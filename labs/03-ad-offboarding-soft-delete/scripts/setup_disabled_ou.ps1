[CmdletBinding()]
param(
    [string]$OuName = "Disabled Users"
)

Import-Module ActiveDirectory -ErrorAction Stop

$domainDN = (Get-ADDomain).DistinguishedName
$ouDN = "OU=$OuName,$domainDN"

$existing = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ouDN)" -ErrorAction SilentlyContinue
if (-not $existing) {
    New-ADOrganizationalUnit -Name $OuName -Path $domainDN -ProtectedFromAccidentalDeletion $false
    Write-Host "Created OU: $ouDN"
} else {
    Write-Host "OU exists: $ouDN"
}

Write-Host "Target OU DN: $ouDN"
