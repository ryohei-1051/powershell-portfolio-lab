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
        param([string]$BaseKey, [string]$Arch)

        $items = @()
        $subkeys = Get-ChildItem -Path $BaseKey -ErrorAction SilentlyContinue

        foreach ($sk in $subkeys) {
            try {
                $k = Get-ItemProperty -Path $sk.PSPath -ErrorAction Stop

                $name = [string]$k.DisplayName
                if ([string]::IsNullOrWhiteSpace($name)) { continue }

                # Skip some noise
                # if ($k.SystemComponent -eq 1) { continue }

                # Optional: this can remove too much in some environments
                # if (-not [string]::IsNullOrWhiteSpace([string]$k.ParentKeyName)) { continue }

                # Apply exclude patterns (DisplayName)
                $skip = $false
                foreach ($p in $ExcludePattern) {
                    if ($name -like $p) { $skip = $true; break }
                }
                if ($skip) { continue }

                $obj = [pscustomobject]@{
                    Target         = $Target
                    ComputerName   = $env:COMPUTERNAME
                    Architecture   = $Arch
                    DisplayName    = $name
                    DisplayVersion = [string]$k.DisplayVersion
                    Publisher      = [string]$k.Publisher
                    InstallDate    = [string]$k.InstallDate
                }

                if ($IncludeSensitiveFields) {
                    $obj | Add-Member -NotePropertyName InstallLocation -NotePropertyValue ([string]$k.InstallLocation) -Force
                    $obj | Add-Member -NotePropertyName UninstallString  -NotePropertyValue ([string]$k.UninstallString)  -Force
                }

                $items += $obj
            } catch {
                # ignore bad keys and continue
            }
        }

        $items
    }

    $apps = @()
    $apps += Get-UninstallApps "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "x64"
    $apps += Get-UninstallApps "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" "x86"

    # IMPORTANT: return objects from the scriptblock
    $apps | Sort-Object DisplayName,DisplayVersion,Publisher -Unique
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
            Invoke-Command -ComputerName $c -Credential $Credential -ScriptBlock $sb `
                -ArgumentList $c,$ExcludePattern,$IncludeSensitiveFields.IsPresent -ErrorAction Stop
        } else {
            Invoke-Command -ComputerName $c -ScriptBlock $sb `
                -ArgumentList $c,$ExcludePattern,$IncludeSensitiveFields.IsPresent -ErrorAction Stop
        }

        $count = ($result | Measure-Object).Count
        if ($count -gt 0) { $allApps += $result }

        $hostname = if ($count -gt 0) { $result[0].ComputerName } else { "" }

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
$allApps |
  Select-Object Target,ComputerName,Architecture,DisplayName,DisplayVersion,Publisher,InstallDate |
  Export-Csv -Path $invPath -NoTypeInformation

$hostStatus |
  Select-Object ComputerName,Status,Hostname,AppsFound,Error,Timestamp |
  Export-Csv -Path $statusPath -NoTypeInformation

Write-Host "Inventory report saved: $invPath"
Write-Host "Status report saved:    $statusPath"
Write-Host ("Total inventory rows:   {0}" -f (($allApps | Measure-Object).Count))
