# Lab 02: AD Group Management (Bulk Add/Remove)

## Overview
Bulk add/remove AD users to/from AD groups using a CSV input file.  
The script generates a timestamped report in `reports/`.

> My lab domain: `ryohei.azlab` (`DC=ryohei,DC=azlab`).  
> Template values are generic for public use.

## Files
- `scripts/setup_groups.ps1` (optional prereq helper)
- `scripts/group_membership.ps1`
- `data/group_membership.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- Windows + RSAT ActiveDirectory module
- Permissions to modify group membership

## CSV Template
`data/group_membership.template.csv`

Columns:
- `username` (SamAccountName)
- `group` (group name or DN)
- `action` (`add` or `remove`)

Example:
```csv
username,group,action
jsmith,HR-Users,add
jdoe,VPN-Users,remove
```

## Setup (optional)
Create the lab groups if they do not exist:
```powershell
cd .\labs\02-ad-group-management\
.\scripts\setup_groups.ps1

## Evidence
- Screenshot: `screenshots/run-whatif-and-real.png`
- Expected output: `screenshots/expected-output.txt`
- Verification: `screenshots/verification-output.txt`
- Sample report: `reports/sample-report.csv`
