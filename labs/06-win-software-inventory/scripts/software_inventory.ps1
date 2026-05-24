<#
.SYNOPSIS
  Multi-machine software inventory (registry-based) via WinRM.

.DESCRIPTION
  Reads ComputerName list from CSV, connects via PowerShell Remoting (WinRM),
  collects installed software from registry Uninstall keys (x64 + WOW6432Node),
  and exports:
    - software_inventory_<timestamp>.csv
    - computer_status_<timestamp>.csv

.NOTES
  PowerShell 5.1 compatible.
  Avoids Win32_Product (slow + side effects).
#>

[CmdletBinding()]
param(
    [string]$CsvPath   = (Join-Path $PSScriptRoot "..\data\computers.template.csv"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),

    [System.Management.Automation.PSCredential]$Credential,

    [switch]$ConnectivityOnly,

    # Optional noise reduction
    [string[]]$ExcludePattern = @("*Update*","*Hotfix*","*Security Update*"),

    # If set, include InstallLocation / UninstallString (can be noisy/sensitive)
    [switch]$IncludeSensitiveFields
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
$invPath   = Join-Path $ReportDir "software_inventory_$ts.csv"
$statusPath= Join-Path $ReportDir "computer_status_$ts.csv"

$allApps = @()
$hostStatus = @()

# Remote collection scriptblock
$sb = {
    param(
        [string]$Target,
        [string[]]$ExcludePattern,
        [bool]$IncludeSensitiveFields
    )

    function Get-UninstallApps {
        param([string]$RegPath, [string]$Arch)

        $items = @()
        try {
            $keys = Get-ItemProperty -Path $RegPath -ErrorAction Stop
            foreach ($k in $keys) {
                $name = [string]$k.DisplayName
                if ([string]::IsNullOrWhiteSpace($name)) { continue }

                # Skip system components / parents where possible
                if ($k.SystemComponent -eq 1) { continue }
                if (-not [string]::IsNullOrWhiteSpace([string]$k.ParentKeyName)) { continue }

                $publisher = [string]$k.Publisher
                $version   = [string]$k.DisplayVersion
                $installDt = [string]$k.InstallDate

                # Noise filtering (pattern applies to DisplayName)
                $skip = $false
                foreach ($p in $ExcludePattern) {
                    if ($name -like $p) { $skip = $true; break }
                }
                if ($skip) { continue }

                $obj = [pscustomobject]@{
                    Target       = $Target
                    ComputerName = $env:COMPUTERNAME
                    Architecture = $Arch
                    DisplayName  = $name
                    DisplayVersion = $version
                    Publisher    = $publisher
                    InstallDate  = $installDt
                }

                if ($IncludeSensitiveFields) {
                    $obj | Add-Member -NotePropertyName InstallLocation -NotePropertyValue ([string]$k.InstallLocation) -Force
                    $obj | Add-Member -NotePropertyName UninstallString  -NotePropertyValue ([string]$k.UninstallString)  -Force
                }

                $items += $obj
            }
        } catch {
            # If a hive/path doesn't exist, just return nothing
        }
        return $items
    }

    $apps = @()

    # 64-bit uninstall keys
    $apps += Get-UninstallApps -RegPath "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -Arch "x64"
    # 32-bit apps on 64-bit OS
    $apps += Get-UninstallApps -RegPath "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -Arch "x86"

    # de-dup (DisplayName + Version + Publisher)
    $apps = $apps | Sort-Object DisplayName,DisplayVersion,Publisher -Unique

    $apps
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
            Invoke-Command -ComputerName $c -Credential $Credential -ScriptBlock $sb -ArgumentList $c,$ExcludePattern,$IncludeSensitiveFields.IsPresent -ErrorAction Stop
        } else {
            Invoke-Command -ComputerName $c -ScriptBlock $sb -ArgumentList $c,$ExcludePattern,$IncludeSensitiveFields.IsPresent -ErrorAction Stop
        }

        $count = ($result | Measure-Object).Count
        if ($count -gt 0) { $allApps += $result }

        # Capture hostname if any records exist; otherwise leave blank
        $hostname = ""
        if ($count -gt 0) { $hostname = $result[0].ComputerName }

        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Success"
            Error        = ""
            Hostname     = $hostname
            AppsFound    = $count
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

# Export
$allApps | Export-Csv -Path $invPath -NoTypeInformation
$hostStatus | Export-Csv -Path $statusPath -NoTypeInformation

Write-Host "Inventory report saved: $invPath"
Write-Host "Status report saved:    $statusPath"
Write-Host ("Total inventory rows:   {0}" -f (($allApps | Measure-Object).Count))
