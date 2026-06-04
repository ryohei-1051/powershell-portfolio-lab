[CmdletBinding()]
param(
    [string]$CsvPath   = (Join-Path $PSScriptRoot "..\data\computers.template.csv"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),

    [System.Management.Automation.PSCredential]$Credential,

    [int]$HotfixTop = 20,
    [switch]$ConnectivityOnly
)

if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

# Load targets
try {
    $resolvedCsv = Resolve-Path -Path $CsvPath -ErrorAction Stop
    $computers = Import-Csv -Path $resolvedCsv -ErrorAction Stop |
        ForEach-Object { ([string]$_.ComputerName).Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique
} catch {
    throw "CSV not found or unreadable: $CsvPath"
}

if (-not $computers -or $computers.Count -eq 0) {
    throw "No ComputerName entries found in: $CsvPath"
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$statusPath = Join-Path $ReportDir "computer_status_$ts.csv"
$detailPath = Join-Path $ReportDir "patch_reboot_readiness_$ts.csv"

$hostStatus = @()
$detailRows = @()

$sb = {
    param([string]$Target, [int]$HotfixTop)

    # Uptime / last boot (CIM may return DateTime or DMTF string)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $raw = $os.LastBootUpTime
    if ($raw -is [string]) {
        $lastBoot = [System.Management.ManagementDateTimeConverter]::ToDateTime($raw)
    } else {
        $lastBoot = [datetime]$raw
    }
    $uptimeHours = [math]::Round(((Get-Date) - $lastBoot).TotalHours, 2)

    # Latest hotfix (Get-HotFix is usually reliable; return just the latest date + KB list)
    $hotfixes = @()
    $latestHotfixDate = $null
    try {
        $hotfixes = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First $HotfixTop
        if ($hotfixes -and $hotfixes.Count -gt 0) {
            $latestHotfixDate = $hotfixes[0].InstalledOn
        }
    } catch {
        # Some builds can block Get-HotFix; keep going
    }

    # Pending reboot checks (common signals)
    $pendingFlags = New-Object System.Collections.Generic.List[string]

    # Component Based Servicing
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $pendingFlags.Add("CBS_RebootPending")
    }

    # Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $pendingFlags.Add("WU_RebootRequired")
    }

    # Pending file rename operations
    try {
        $p = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction Stop
        if ($p.PendingFileRenameOperations) { $pendingFlags.Add("PendingFileRenameOperations") }
    } catch { }

    # Server Manager (often present on Server OS)
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts") {
        $pendingFlags.Add("ServerManager_RebootHint")
    }

    $pendingReboot = ($pendingFlags.Count -gt 0)

    [pscustomobject]@{
        Target            = $Target
        ComputerName      = $env:COMPUTERNAME
        LastBootTime      = $lastBoot
        UptimeHours       = $uptimeHours
        LatestHotfixDate  = $latestHotfixDate
        LatestHotfixKBs   = if ($hotfixes) { ($hotfixes | Select-Object -ExpandProperty HotFixID) -join ";" } else { "" }
        PendingReboot     = $pendingReboot
        PendingReasons    = if ($pendingFlags.Count -gt 0) { $pendingFlags -join ";" } else { "" }
        Timestamp         = Get-Date
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
            Invoke-Command -ComputerName $c -Credential $Credential -ScriptBlock $sb -ArgumentList $c,$HotfixTop -ErrorAction Stop
        } else {
            Invoke-Command -ComputerName $c -ScriptBlock $sb -ArgumentList $c,$HotfixTop -ErrorAction Stop
        }

        if (-not $result) { throw "No data returned from remote scriptblock." }

        $detailRows += $result

        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Success"
            Hostname     = $result.ComputerName
            PendingReboot= $result.PendingReboot
            LatestHotfixDate = $result.LatestHotfixDate
            Error        = ""
            Timestamp    = Get-Date
        }
    } catch {
        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Failed"
            Hostname     = ""
            PendingReboot= ""
            LatestHotfixDate = ""
            Error        = $_.Exception.Message
            Timestamp    = Get-Date
        }
    }
}

# Export (clean columns)
$hostStatus |
  Select-Object ComputerName,Status,Hostname,PendingReboot,LatestHotfixDate,Error,Timestamp |
  Export-Csv -Path $statusPath -NoTypeInformation

$detailRows |
  Select-Object Target,ComputerName,LastBootTime,UptimeHours,LatestHotfixDate,LatestHotfixKBs,PendingReboot,PendingReasons,Timestamp |
  Export-Csv -Path $detailPath -NoTypeInformation

Write-Host "Status report saved:  $statusPath"
Write-Host "Detail report saved:  $detailPath"
Write-Host ("Total detail rows:    {0}" -f (($detailRows | Measure-Object).Count))
