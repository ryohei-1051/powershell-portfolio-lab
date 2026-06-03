[CmdletBinding()]
param(
    [string]$ComputersCsvPath = (Join-Path $PSScriptRoot "..\data\computers.template.csv"),
    [string]$ServicesCsvPath  = (Join-Path $PSScriptRoot "..\data\services.template.csv"),
    [string]$ReportDir        = (Join-Path $PSScriptRoot "..\reports"),
    [System.Management.Automation.PSCredential]$Credential,
    [switch]$ConnectivityOnly
)

if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

# Load targets
$computers = Import-Csv $ComputersCsvPath |
    ForEach-Object { ([string]$_.ComputerName).Trim() } |
    Where-Object { $_ } |
    Select-Object -Unique

if (-not $computers -or $computers.Count -eq 0) {
    throw "No ComputerName entries found in: $ComputersCsvPath"
}

# Load services list (Name, not DisplayName)
$services = Import-Csv $ServicesCsvPath |
    ForEach-Object { ([string]$_.ServiceName).Trim() } |
    Where-Object { $_ } |
    Select-Object -Unique

if (-not $services -or $services.Count -eq 0) {
    throw "No ServiceName entries found in: $ServicesCsvPath"
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$statusPath = Join-Path $ReportDir "computer_status_$ts.csv"
$diskPath   = Join-Path $ReportDir "disk_usage_$ts.csv"
$svcPath    = Join-Path $ReportDir "critical_services_$ts.csv"

$hostStatus = @()
$diskRows   = @()
$svcRows    = @()

# Remote scriptblock
$sb = {
    param([string]$Target, [string[]]$ServiceNames)

    # OS / uptime (CIM may return DateTime or DMTF string depending on host/provider)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $raw = $os.LastBootUpTime
    if ($raw -is [string]) {
        $lastBoot = [System.Management.ManagementDateTimeConverter]::ToDateTime($raw)
    } else {
        $lastBoot = [datetime]$raw
    }
    $uptimeHours = [math]::Round(((Get-Date) - $lastBoot).TotalHours, 2)

    # Disk usage (fixed drives)
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop |
        ForEach-Object {
            $sizeGB  = if ($_.Size)      { [math]::Round($_.Size / 1GB, 2) } else { 0 }
            $freeGB  = if ($_.FreeSpace) { [math]::Round($_.FreeSpace / 1GB, 2) } else { 0 }
            $freePct = if ($_.Size -gt 0){ [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 }

            [pscustomobject]@{
                Target       = $Target
                ComputerName = $env:COMPUTERNAME
                DriveLetter  = $_.DeviceID
                VolumeName   = $_.VolumeName
                SizeGB       = $sizeGB
                FreeGB       = $freeGB
                FreePct      = $freePct
                Timestamp    = Get-Date
            }
        }

    # Critical services
    $svcOut = foreach ($name in $ServiceNames) {
        try {
            $s = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction Stop
            [pscustomobject]@{
                Target       = $Target
                ComputerName = $env:COMPUTERNAME
                ServiceName  = $s.Name
                DisplayName  = $s.DisplayName
                State        = $s.State
                StartMode    = $s.StartMode
                Timestamp    = Get-Date
            }
        } catch {
            [pscustomobject]@{
                Target       = $Target
                ComputerName = $env:COMPUTERNAME
                ServiceName  = $name
                DisplayName  = ""
                State        = "NotFound"
                StartMode    = ""
                Timestamp    = Get-Date
            }
        }
    }

    [pscustomobject]@{
        Target       = $Target
        ComputerName = $env:COMPUTERNAME
        LastBootTime = $lastBoot
        UptimeHours  = $uptimeHours
        Disks        = $disks
        Services     = $svcOut
    }
}

foreach ($c in $computers) {
    Write-Verbose "Processing: $c"

    if ($ConnectivityOnly) {
        try {
            Test-WSMan -ComputerName $c -ErrorAction Stop | Out-Null
            $hostStatus += [pscustomobject]@{
                ComputerName = $c
                Status       = "Connected"
                Hostname     = ""
                LastBootTime = ""
                UptimeHours  = ""
                Error        = ""
                Timestamp    = Get-Date
            }
        } catch {
            $hostStatus += [pscustomobject]@{
                ComputerName = $c
                Status       = "Failed"
                Hostname     = ""
                LastBootTime = ""
                UptimeHours  = ""
                Error        = $_.Exception.Message
                Timestamp    = Get-Date
            }
        }
        continue
    }

    try {

        $diskRows += @($result.Disks)
        $svcRows  += @($result.Services)

        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Success"
            Hostname     = $result.ComputerName
            LastBootTime = $result.LastBootTime
            UptimeHours  = $result.UptimeHours
            Error        = ""
            Timestamp    = Get-Date
        }
    } catch {
        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Failed"
            Hostname     = ""
            LastBootTime = ""
            UptimeHours  = ""
            Error        = $_.Exception.Message
            Timestamp    = Get-Date
        }
    }
}

# Export (clean columns)
$hostStatus |
  Select-Object ComputerName,Status,Hostname,LastBootTime,UptimeHours,Error,Timestamp |
  Export-Csv -Path $statusPath -NoTypeInformation

$diskRows |
  Select-Object Target,ComputerName,DriveLetter,VolumeName,SizeGB,FreeGB,FreePct,Timestamp |
  Export-Csv -Path $diskPath -NoTypeInformation

$svcRows |
  Select-Object Target,ComputerName,ServiceName,DisplayName,State,StartMode,Timestamp |
  Export-Csv -Path $svcPath -NoTypeInformation

Write-Host "Status report saved:   $statusPath"
Write-Host "Disk report saved:     $diskPath"
Write-Host "Services report saved: $svcPath"
