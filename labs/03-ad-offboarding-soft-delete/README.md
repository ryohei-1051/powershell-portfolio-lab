# Lab 03: AD Offboarding (Soft Delete)

## Overview
Soft offboarding workflow using PowerShell + CSV:
- Disable account
- Move user to a Disabled Users OU
- Optional: remove from non-default groups
- Export a timestamped report to `reports/`

> My lab domain: `ryohei.azlab` (`DC=ryohei,DC=azlab`).  
> Template values use placeholders for public use.

## Files
- `scripts/setup_disabled_ou.ps1`
- `scripts/offboard_users.ps1`
- `data/offboard_users.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- Windows + RSAT ActiveDirectory module
- Permissions to disable/move users and modify group membership

## Setup
Create the Disabled Users OU:
```powershell
cd .\labs\03-ad-offboarding-soft-delete\
.\scripts\setup_disabled_ou.ps1
```

## CSV Template
`data/offboard_users.template.csv`

Columns:
`username` (SamAccountName)
`targetOU` (optional; defaults to `OU=Disabled Users,<domainDN>`)
`removeFromGroups` (`true/false`)

Example:
```csv
username,targetOU,removeFromGroups
ECarter,"OU=Disabled Users,DC=example,DC=local",true
DWright,"OU=Disabled Users,DC=example,DC=local",true
SMitchell,"OU=Disabled Users,DC=example,DC=local",true
ERamirez,"OU=Disabled Users,DC=example,DC=local",true
OBennett,"OU=Disabled Users,DC=example,DC=local",true
JFoster,"OU=Disabled Users,DC=example,DC=local",true
MHoward,"OU=Disabled Users,DC=example,DC=local",true
LTorres,"OU=Disabled Users,DC=example,DC=local",true
AMurphy,"OU=Disabled Users,DC=example,DC=local",true
NHughes,"OU=Disabled Users,DC=example,DC=local",true
```
Replace `DC=example,DC=local` with your domain DN or leave blank.

## Run
Dry run:
```powershell
.\scripts\offboard_users.ps1 -WhatIf
```

Real run:
```powershell
.\scripts\offboard_users.ps1
```

## Verification
```powershell
Get-ADUser -Identity "ECarter" -Properties Enabled,DistinguishedName | Select SamAccountName,Enabled,DistinguishedName
Get-ADPrincipalGroupMembership -Identity "ECarter" | Select Name
```

## Output
A report is saved to `reports/`:
`offboard_YYYYMMDD_HHMMSS.csv`
