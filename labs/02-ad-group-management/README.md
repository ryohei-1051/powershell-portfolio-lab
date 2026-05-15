
## 2) Add the missing “completion” sections
To make Lab 02 portfolio-complete, add:

- **Setup (optional)**: create `HR-Users` / `VPN-Users` groups (since they don’t exist by default in a fresh domain)
- **Run**: show `-WhatIf` first, then real run
- **Verification + Evidence**: verify membership and point to screenshot/report files

---

## Paste-ready improved `labs/02-ad-group-management/README.md`
(You can replace your README with this.)

```markdown
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
