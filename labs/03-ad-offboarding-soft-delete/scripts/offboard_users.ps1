[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CsvPath    = (Join-Path $PSScriptRoot "..\data\offboard_users.template.csv"),
    [string]$ReportDir  = (Join-Path $PSScriptRoot "..\reports"),
    [string]$DefaultDisabledOuName = "Disabled Users"
)

Import-Module ActiveDirectory -ErrorAction Stop

# Ensure report directory exists
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $ReportDir "offboard_$timestamp.csv"

# Resolve default disabled OU DN dynamically
$domainDN = (Get-ADDomain).DistinguishedName
$defaultTargetOu = "OU=$DefaultDisabledOuName,$domainDN"

# Read CSV
try {
    $resolvedCsv = Resolve-Path -Path $CsvPath -ErrorAction Stop
    $rows = Import-Csv -Path $resolvedCsv -ErrorAction Stop
} catch {
    throw "CSV not found or unreadable: $CsvPath"
}

$results = @()

foreach ($r in $rows) {
    $username = (($r.username -as [string]) ?? "").Trim()
    $targetOU = (($r.targetOU -as [string]) ?? "").Trim()
    $removeFromGroups = (($r.removeFromGroups -as [string]) ?? "").Trim().ToLower()

    if ([string]::IsNullOrWhiteSpace($username)) { continue }

    if ([string]::IsNullOrWhiteSpace($targetOU)) { $targetOU = $defaultTargetOu }
    $doRemoveGroups = $removeFromGroups -in @("true","yes","1")

    $status = "Failed"
    $reason = ""
    $groupsRemoved = 0

    # Lookup user (LDAPFilter returns $null if not found)
    $userObj = Get-ADUser -LDAPFilter "(sAMAccountName=$username)" -ErrorAction SilentlyContinue
    if (-not $userObj) {
        $results += [pscustomobject]@{
            username=$username; status="Skipped"; reason="User not found"; targetOU=$targetOU;
            disabled=$false; moved=$false; groupsRemoved=0; timestamp=(Get-Date)
        }
        continue
    }

    # Validate target OU exists
    $ouObj = Get-ADOrganizationalUnit -Identity $targetOU -ErrorAction SilentlyContinue
    if (-not $ouObj) {
        $results += [pscustomobject]@{
            username=$username; status="Skipped"; reason="Target OU not found"; targetOU=$targetOU;
            disabled=$false; moved=$false; groupsRemoved=0; timestamp=(Get-Date)
        }
        continue
    }

    $didDisable = $false
    $didMove    = $false

    try {
        # Disable account
        if ($PSCmdlet.ShouldProcess($username, "Disable-ADAccount")) {
            Disable-ADAccount -Identity $userObj -ErrorAction Stop
        }
        $didDisable = $true

        # Move to Disabled OU
        if ($PSCmdlet.ShouldProcess($username, "Move-ADObject to $targetOU")) {
            Move-ADObject -Identity $userObj.DistinguishedName -TargetPath $targetOU -ErrorAction Stop
        }
        $didMove = $true

        # Optional group cleanup (keep Domain Users)
        if ($doRemoveGroups) {
            $groups = Get-ADPrincipalGroupMembership -Identity $userObj -ErrorAction Stop |
                      Where-Object { $_.Name -ne "Domain Users" }

            foreach ($g in $groups) {
                try {
                    if ($PSCmdlet.ShouldProcess("$username -> $($g.Name)", "Remove-ADGroupMember")) {
                        Remove-ADGroupMember -Identity $g -Members $userObj -Confirm:$false -ErrorAction Stop
                    }
                    $groupsRemoved++
                } catch {
                    # keep going, but record the first failure message
                    if ([string]::IsNullOrWhiteSpace($reason)) {
                        $reason = "Group removal error: $($_.Exception.Message)"
                    }
                }
            }
        }

        $status = "Success"
        if ([string]::IsNullOrWhiteSpace($reason)) { $reason = "Offboarded" }

    } catch {
        $status = "Failed"
        if ([string]::IsNullOrWhiteSpace($reason)) {
            $reason = $_.Exception.Message
        }
    }

    $results += [pscustomobject]@{
        username=$username; status=$status; reason=$reason; targetOU=$targetOU;
        disabled=$didDisable; moved=$didMove; groupsRemoved=$groupsRemoved; timestamp=(Get-Date)
    }
}

$results | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Report saved: $reportPath"
