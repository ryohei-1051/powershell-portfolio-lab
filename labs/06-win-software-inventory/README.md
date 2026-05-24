# Lab 06: Windows Software Inventory (Multi-machine)

## Overview
Collect installed software inventory across multiple Windows machines from a CSV list using WinRM (PowerShell Remoting).

This lab uses registry-based inventory (Uninstall keys) and avoids `Win32_Product` (slow + side effects).

## Files
- `scripts/software_inventory.ps1`
- `data/computers.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- PowerShell 5.1+
- Network connectivity to targets
- WinRM enabled on targets (recommended)
- Permissions to read HKLM uninstall keys on targets (local admin is safest)

## WinRM quick setup (domain lab)
Run on each target (Admin):
```powershell
Enable-PSRemoting -Force
```
