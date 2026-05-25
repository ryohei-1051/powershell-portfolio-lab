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

From the collector:
```powershell
Test-WSMan -ComputerName <TARGET>
```

## CSV input
`data/computers.template.csv`
```csv
ComputerName
CLIENT1.ryohei.azlab
Lab4Server.ryohei.azlab
```
## Run
From the lab folder:
```powershell
cd .\labs\06-win-software-inventory\

# 1) Connectivity-only
.\scripts\software_inventory.ps1 -ConnectivityOnly -Verbose

# 2) Full inventory
.\scripts\software_inventory.ps1 -Verbose
```
### Optional: run with explicit credentials
```powershell
$cred = Get-Credential
.\scripts\software_inventory.ps1 -Credential $cred -Verbose
```

## Output
Two CSV reports are generated in `reports/`:
- `software_inventory_YYYYMMDD_HHMMSS.csv`
- `computer_status_YYYYMMDD_HHMMSS.csv`

## Interpretation
- Inventory can include software that is expected to be present (drivers, components, vendor tools).
- Not every entry is "actionable"—treat the report as a visibility tool.

## Public sharing note
Software inventories may reveal environment-specific tools. If publishing sample outputs:
- commit only a small sample report, and/or
- exclude sensitive tools, and/or
- avoid enabling `-IncludeSensitiveFields`.

## Evidence (screenshots)
- Script run output showing report paths
- Opened `computer_status_*.csv`
- Opened `software_inventory_*.csv`
