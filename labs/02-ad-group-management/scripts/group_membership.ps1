[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot "..\data\group_membership.template.csv"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports")
)

Import-Module ActiveDirectory -ErrorAction Stop

# Ensure report directory exists
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $ReportDir "group_membership_$timestamp.csv"

$rows = Import-Csv -Path $CsvPath -ErrorAction Stop
$results = @()

foreach ($r in $rows) {
    $username = ($r.username  -as [string]).Trim()
    $group    = ($r.group     -as [string]).Trim()
    $action   = ($r.action    -as [string]).Trim().ToLower()

    if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($group) -or [string]::IsNullOrWhiteSpace($action)) {
        continue
    }

    $status = "Failed"
    $reason = ""

    try {
        $userObj = Get-ADUser -LDAPFilter "(sAMAccountName=$username)" -ErrorAction Stop
    } catch {
        $status = "Skipped"
        $reason = "User not found"
        $results += [pscustomobject]@{ username=$username; group=$group; action=$action; status=$status; reason=$reason; timestamp=(Get-Date) }
        continue
    }

    try {
        $groupObj = Get-ADGroup -Identity $group -ErrorAction Stop
    } catch {
        $status = "Skipped"
        $reason = "Group not found"
        $results += [pscustomobject]@{ username=$username; group=$group; action=$action; status=$status; reason=$reason; timestamp=(Get-Date) }
        continue
    }

    try {
        if ($action -eq "add") {
            if ($PSCmdlet.ShouldProcess("$username -> $group", "Add member to group")) {
                Add-ADGroupMember -Identity $groupObj -Members $userObj -ErrorAction Stop
            }
            $status = "Success"
            $reason = "Added"
        }
        elseif ($action -eq "remove") {
            if ($PSCmdlet.ShouldProcess("$username -> $group", "Remove member from group")) {
                Remove-ADGroupMember -Identity $groupObj -Members $userObj -Confirm:$false -ErrorAction Stop
            }
            $status = "Success"
            $reason = "Removed"
        }
        else {
            $status = "Skipped"
            $reason = "Invalid action (use add/remove)"
        }
    } catch {
        $status = "Failed"
        $reason = $_.Exception.Message
    }

    $results += [pscustomobject]@{
        username  = $username
        group     = $group
        action    = $action
        status    = $status
        reason    = $reason
        timestamp = Get-Date
    }
}

$results | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Report saved: $reportPath"
