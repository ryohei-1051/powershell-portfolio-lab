# Lab 02: AD Group Management (Bulk Add/Remove)

## Overview
Bulk add/remove AD users to/from AD groups using a CSV file.

## Structure
- `scripts/group_membership.ps1`
- `data/group_membership.template.csv`
- `reports/` (script outputs a timestamped CSV report)

## Requirements
- Windows + RSAT ActiveDirectory module
- Permissions to modify group membership

## CSV Template
`data/group_membership.template.csv`

Columns:
- `username` (SamAccountName)
- `group` (group name or DN)
- `action` (`add` or `remove`)

## Run
From the lab folder:

```powershell
cd .\labs\02-ad-group-management\
.\scripts\group_membership.ps1 -WhatIf
