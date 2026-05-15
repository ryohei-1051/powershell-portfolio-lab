Import-Module ActiveDirectory -ErrorAction Stop
$domainDN = (Get-ADDomain).DistinguishedName
$usersCN = "CN=Users,$domainDN"

foreach ($g in @("HR-Users","VPN-Users")) {
  if (-not (Get-ADGroup -LDAPFilter "(cn=$g)" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $g -SamAccountName $g -GroupScope Global -GroupCategory Security -Path $usersCN
    Write-Host "Created group: $g"
  } else {
    Write-Host "Group exists: $g"
  }
}