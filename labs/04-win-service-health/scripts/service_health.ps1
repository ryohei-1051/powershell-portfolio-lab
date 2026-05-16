<#
.SYNOPSIS
  Multi-machine Windows Service Health report (Auto-start services not running).

.DESCRIPTION
  Reads ComputerName list from CSV, connects via CIM over WinRM (WSMan),
  queries Win32_Service, and reports services where:
    StartMode = Auto AND State != Running

  Exports:
    - service_issues_<timestamp>.csv
    - computer_status_<timestamp>.csv

.NOTES
  PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    [string]$CsvPath   = (Join-Path $PSScriptRoot "..\data\computers.template.csv"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),

    # WinRM (WSMan) is default. Optionally fallback to DCOM if WSMan fails.
    [ValidateSet("Wsman","Dcom")]
    [string]$Protocol = "Wsman",

    [switch]$UseDcomFallback,

    # If omitted, uses current credentials.
    [System.Management.Automation.PSCredential]$Credential,

    # Optional filters
    [string[]]$IncludeName,   # service Name exact matches (e.g. "w32time")
    [string[]]$ExcludeName,   # service Name exact matches
    [string[]]$ExcludePattern # wildcard patterns (e.g. "*OneDrive*","*Teams*")

    ,
    [switch]$ConnectivityOnly # only test connectivity/session creation
)

function New-LabCimSession {
    param(
        [string]$ComputerName,
        [string]$Protocol,
        [System.Management.Automation.PSCredential]$Credential
    )

    $opt = New-CimSessionOption -Protocol $Protocol
    if ($Credential) {
        return New-CimSession -ComputerName $ComputerName -Credential $Credential -SessionOption $opt -ErrorAction Stop
    } else {
        return New-CimSession -ComputerName $ComputerName -SessionOption $opt -ErrorAction Stop
    }
}

# Ensure report directory exists
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

# Load computer list
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
$issuesPath = Join-Path $ReportDir "service_issues_$ts.csv"
$statusPath = Join-Path $ReportDir "computer_status_$ts.csv"

$issues = @()
$hostStatus = @()

foreach ($c in $computers) {
    Write-Verbose "Processing: $c"

    $session = $null
    $usedProtocol = $Protocol

    try {
        # Try primary protocol
        $session = New-LabCimSession -ComputerName $c -Protocol $Protocol -Credential $Credential

    } catch {
        if ($UseDcomFallback -and $Protocol -eq "Wsman") {
            Write-Verbose "WSMan failed for $c, trying DCOM fallback..."
            try {
                $session = New-LabCimSession -ComputerName $c -Protocol "Dcom" -Credential $Credential
                $usedProtocol = "Dcom"
            } catch {
                $hostStatus += [pscustomobject]@{
                    ComputerName = $c
                    Status       = "Failed"
                    Protocol     = $Protocol
                    Error        = $_.Exception.Message
                    Timestamp    = Get-Date
                }
                continue
            }
        } else {
            $hostStatus += [pscustomobject]@{
                ComputerName = $c
                Status       = "Failed"
                Protocol     = $Protocol
                Error        = $_.Exception.Message
                Timestamp    = Get-Date
            }
            continue
        }
    }

    try {
        if ($ConnectivityOnly) {
            $hostStatus += [pscustomobject]@{
                ComputerName = $c
                Status       = "Connected"
                Protocol     = $usedProtocol
                Error        = ""
                Timestamp    = Get-Date
            }
            continue
        }

        $svcs = Get-CimInstance -CimSession $session -ClassName Win32_Service -ErrorAction Stop

        # Filter: Auto-start not running
        $bad = $svcs | Where-Object {
            $_.StartMode -eq "Auto" -and $_.State -ne "Running"
        }

        # Apply optional filters
        if ($IncludeName -and $IncludeName.Count -gt 0) {
            $bad = $bad | Where-Object { $IncludeName -contains $_.Name }
        }
        if ($ExcludeName -and $ExcludeName.Count -gt 0) {
            $bad = $bad | Where-Object { $ExcludeName -notcontains $_.Name }
        }
        if ($ExcludePattern -and $ExcludePattern.Count -gt 0) {
            foreach ($p in $ExcludePattern) {
                $bad = $bad | Where-Object { $_.Name -notlike $p -and $_.DisplayName -notlike $p }
            }
        }

        foreach ($s in $bad) {
            $issues += [pscustomobject]@{
                ComputerName      = $c
                Protocol          = $usedProtocol
                Name              = $s.Name
                DisplayName       = $s.DisplayName
                State             = $s.State
                StartMode         = $s.StartMode
                DelayedAutoStart  = $s.DelayedAutoStart
                StartName         = $s.StartName
                ProcessId         = $s.ProcessId
                Timestamp         = Get-Date
            }
        }

        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Success"
            Protocol     = $usedProtocol
            Error        = ""
            TotalServices= $svcs.Count
            IssuesFound  = ($bad | Measure-Object).Count
            Timestamp    = Get-Date
        }

    } catch {
        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Failed"
            Protocol     = $usedProtocol
            Error        = $_.Exception.Message
            Timestamp    = Get-Date
        }
    }
    finally {
        if ($session) { Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue }
    }
}

# Export reports
$issues | Export-Csv -Path $issuesPath -NoTypeInformation
$hostStatus | Export-Csv -Path $statusPath -NoTypeInformation

Write-Host "Issues report saved:  $issuesPath"
Write-Host "Status report saved:  $statusPath"
Write-Host ("Issues found: {0}" -f $issues.Count)

