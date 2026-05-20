# Lab 05: Windows Local Admins Audit (Multi-machine)

## Overview
Audit **local Administrators group membership** across multiple Windows machines from a CSV list.

This lab uses WinRM (PowerShell Remoting) and resolves the Administrators group by its well-known SID:
- `S-1-5-32-544` (works even if the group name is localized)

## Files
- `scripts/local_admins_audit.ps1`
- `data/computers.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- PowerShell 5.1+
- Network connectivity to targets
- WinRM enabled on targets (recommended)
- Permissions to query local group membership on targets (local admin is safest)

## WinRM quick setup (domain lab)
Run on each target (Admin):
```powershell
Enable-PSRemoting -Force
