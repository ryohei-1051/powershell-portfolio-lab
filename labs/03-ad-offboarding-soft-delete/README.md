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
