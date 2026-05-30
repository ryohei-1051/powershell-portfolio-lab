<#
.SYNOPSIS
  Multi-machine Security log audit (failed logons + account lockouts) via WinRM.

.DESCRIPTION
  Reads ComputerName list from CSV and collects Security log events:
    - 4625: failed logon
    - 4740: account lockout (typically on DCs)

  Exports:
    - computer_status_<timestamp>.csv
    - security_events_<timestamp>.csv
    - security_summary_<timestamp>.csv

.NOTES
  PowerShell 5.1 compatible.
  Security logs may require admin/Event Log Readers rights.
#>

[CmdletBinding()]
param(
    [string]$CsvPath   = (Join-Path $PSScriptRoot "..\data\computers.template.csv"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),

    [System.Management.Automation.PSCredential]$Credential,

    [int]$DaysBack = 1,
    [int]$MaxEventsPerHost = 500,

    [switch]$IncludeSuccessLogons,   # includes 4624 if set
    [switch]$ConnectivityOnly
)

if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

# Load targets
try {
    $resolvedCsv = Resolve-Path -Path $CsvPath -ErrorAction Stop
    $computers = Import-Csv -Path $resolvedCsv -ErrorAction Stop |
        ForEach-Object { ($_."ComputerName" -as [string]).Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
} catch {
    throw "CSV not found or unreadable: $CsvPath"
}

if (-not $computers -or $computers.Count -eq 0) {
    throw "No ComputerName entries found in CSV: $CsvPath"
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$statusPath  = Join-Path $ReportDir "computer_status_$ts.csv"
$eventsPath  = Join-Path $ReportDir "security_events_$ts.csv"
$summaryPath = Join-Path $ReportDir "security_summary_$ts.csv"

$allEvents  = @()
$hostStatus = @()

$sb = {
    param(
        [string]$Target,
        [datetime]$StartTime,
        [int[]]$EventIds,
        [int]$MaxEvents
    )

    function Convert-EventToObject {
        param($EventRecord, [string]$Target)

        $xml = [xml]$EventRecord.ToXml()
        $edata = @{}
        foreach ($d in $xml.Event.EventData.Data) {
            $edata[$d.Name] = $d.'#text'
        }

        $id = [int]$EventRecord.Id

        # Common fields
        $obj = [ordered]@{
            Target        = $Target
            ComputerName  = $env:COMPUTERNAME
            EventId       = $id
            TimeCreated   = $EventRecord.TimeCreated
            Provider      = $EventRecord.ProviderName
            UserName      = ""
            Domain        = ""
            SourceIp      = ""
            Workstation   = ""
            LogonType     = ""
            Status        = ""
            SubStatus     = ""
            CallerComputer= ""
        }

        switch ($id) {
            4625 {
                $obj.UserName    = $edata["TargetUserName"]
                $obj.Domain      = $edata["TargetDomainName"]
                $obj.SourceIp    = $edata["IpAddress"]
                $obj.Workstation = $edata["WorkstationName"]
                $obj.LogonType   = $edata["LogonType"]
                $obj.Status      = $edata["Status"]
                $obj.SubStatus   = $edata["SubStatus"]
            }
            4740 {
                $obj.UserName       = $edata["TargetUserName"]
                $obj.Domain         = $edata["TargetDomainName"]
                $obj.CallerComputer = $edata["CallerComputerName"]
            }
            4624 {
                $obj.UserName    = $edata["TargetUserName"]
                $obj.Domain      = $edata["TargetDomainName"]
                $obj.SourceIp    = $edata["IpAddress"]
                $obj.Workstation = $edata["WorkstationName"]
                $obj.LogonType   = $edata["LogonType"]
            }
            4776 {
                # NTLM credential validation
                $obj.UserName    = $edata["TargetUserName"]
                $obj.Domain      = $edata["TargetDomainName"]
                # Some builds use Workstation; some use WorkstationName
                $obj.Workstation = $edata["Workstation"]
                if (-not $obj.Workstation) { $obj.Workstation = $edata["WorkstationName"] }
                $obj.Status      = $edata["Status"]
            }
        }

        [pscustomobject]$obj
    }

    $events = Get-WinEvent -FilterHashtable @{
        LogName   = "Security"
        Id        = $EventIds
        StartTime = $StartTime
    } -ErrorAction Stop |
      Select-Object -First $MaxEvents

    foreach ($e in $events) {
        Convert-EventToObject -EventRecord $e -Target $Target
    }
}

$startTime = (Get-Date).AddDays(-1 * $DaysBack)
$ids = @(4625, 4740, 4776, 4771)
if ($IncludeSuccessLogons) { $ids += 4624 }

foreach ($c in $computers) {
    Write-Verbose "Processing: $c"

    if ($ConnectivityOnly) {
        try {
            Test-WSMan -ComputerName $c -ErrorAction Stop | Out-Null
            $hostStatus += [pscustomobject]@{
                ComputerName = $c
                Status       = "Connected"
                Error        = ""
                Timestamp    = Get-Date
            }
        } catch {
            $hostStatus += [pscustomobject]@{
                ComputerName = $c
                Status       = "Failed"
                Error        = $_.Exception.Message
                Timestamp    = Get-Date
            }
        }
        continue
    }

    try {
        $result = if ($Credential) {
            Invoke-Command -ComputerName $c -Credential $Credential -ScriptBlock $sb `
                -ArgumentList $c,$startTime,$ids,$MaxEventsPerHost -ErrorAction Stop
        } else {
            Invoke-Command -ComputerName $c -ScriptBlock $sb `
                -ArgumentList $c,$startTime,$ids,$MaxEventsPerHost -ErrorAction Stop
        }

        $count = ($result | Measure-Object).Count
        if ($count -gt 0) { $allEvents += $result }

        $hostname = if ($count -gt 0) { $result[0].ComputerName } else { "" }

        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Success"
            Error        = ""
            Hostname     = $hostname
            EventsFound  = $count
            Timestamp    = Get-Date
        }
    } catch {
        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Failed"
            Error        = $_.Exception.Message
            Timestamp    = Get-Date
        }
    }
}

# Export raw events
$allEvents |
  Select-Object Target,ComputerName,EventId,TimeCreated,Provider,Domain,UserName,SourceIp,Workstation,LogonType,Status,SubStatus,CallerComputer |
  Export-Csv -Path $eventsPath -NoTypeInformation

# Export per-host status
$hostStatus |
  Select-Object ComputerName,Status,Hostname,EventsFound,Error,Timestamp |
  Export-Csv -Path $statusPath -NoTypeInformation

# Export summary (counts)
$summary = $allEvents |
  Group-Object Target,ComputerName,EventId,Domain,UserName,SourceIp,Workstation,CallerComputer |
  ForEach-Object {
      $p = $_.Name -split ', '
      [pscustomobject]@{
          Target        = $p[0]
          ComputerName  = $p[1]
          EventId       = $p[2]
          Domain        = $p[3]
          UserName      = $p[4]
          SourceIp      = $p[5]
          Workstation   = $p[6]
          CallerComputer= $p[7]
          Count         = $_.Count
      }
  }

$summary | Export-Csv -Path $summaryPath -NoTypeInformation

Write-Host "Events report saved:   $eventsPath"
Write-Host "Summary report saved:  $summaryPath"
Write-Host "Status report saved:   $statusPath"
Write-Host ("Total events rows:     {0}" -f (($allEvents | Measure-Object).Count))
