<#
.SYNOPSIS
  Audit Local Administrators group membership across multiple machines.

.DESCRIPTION
  Reads ComputerName list from CSV and uses WinRM (PowerShell Remoting) to collect
  local Administrators group members (well-known SID S-1-5-32-544).

  Exports:
    - local_admins_members_<timestamp>.csv
    - computer_status_<timestamp>.csv

.NOTES
  PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    [string]$CsvPath   = (Join-Path $PSScriptRoot "..\data\computers.template.csv"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),

    # If omitted, uses current credentials (Kerberos in domain lab)
    [System.Management.Automation.PSCredential]$Credential,

    [switch]$ConnectivityOnly
)

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
$membersPath = Join-Path $ReportDir "local_admins_members_$ts.csv"
$statusPath  = Join-Path $ReportDir "computer_status_$ts.csv"

$allMembers = @()
$hostStatus = @()

# Script block executed on each target
$sb = {
    param([string]$Target)

    $adminSid = "S-1-5-32-544"
    $grp = Get-CimInstance -ClassName Win32_Group -Filter "SID='$adminSid'" -ErrorAction Stop
    $groupName = $grp.Name

    $members = Get-LocalGroupMember -Group $groupName -ErrorAction Stop

    $output = foreach ($m in $members) {
        [pscustomobject]@{
            Target          = $Target              # from CSV (FQDN)
            ComputerName    = $env:COMPUTERNAME    # actual hostname
            GroupName       = $groupName
            MemberName      = $m.Name
            ObjectClass     = $m.ObjectClass
            PrincipalSource = $m.PrincipalSource
            Sid             = if ($m.SID) { $m.SID.Value } else { "" }
        }
    }

    [pscustomobject]@{
        Target       = $Target
        Hostname     = $env:COMPUTERNAME
        GroupName    = $groupName
        Members      = $output
    }
}

foreach ($c in $computers) {
    Write-Verbose "Processing: $c"

    # Connectivity-only: just test WSMan
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
        # Invoke command (with optional credential)
        $result = if ($Credential) {
            Invoke-Command -ComputerName $c -Credential $Credential -ScriptBlock $sb -ArgumentList $c -ErrorAction Stop
        } else {
            Invoke-Command -ComputerName $c -ScriptBlock $sb -ArgumentList $c -ErrorAction Stop
        }

        # Collect members
        if ($result -and $result.Members) {
            $allMembers += $result.Members
        }

        $memberCount = if ($result -and $result.Members) { ($result.Members | Measure-Object).Count } else { 0 }

        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Success"
            Error        = ""
            Hostname     = $result.Hostname
            GroupName    = $result.GroupName
            MembersCount = $memberCount
            Timestamp    = Get-Date
        }
    }
    catch {
        $hostStatus += [pscustomobject]@{
            ComputerName = $c
            Status       = "Failed"
            Error        = $_.Exception.Message
            Timestamp    = Get-Date
        }
    }
}

# Export reports
if (-not $ConnectivityOnly) {
    $allMembers | Export-Csv -Path $membersPath -NoTypeInformation
    Write-Host "Members report saved: $membersPath"
} else {
    Write-Host "ConnectivityOnly: skipping members export"
}

if (-not $ConnectivityOnly) {
    Write-Host ("Total members rows:  {0}" -f (($allMembers | Measure-Object).Count))
}

$hostStatus | Export-Csv -Path $statusPath -NoTypeInformation
Write-Host "Status report saved:  $statusPath"
