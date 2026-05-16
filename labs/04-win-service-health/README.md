# Lab 04: Windows Service Health (Multi-machine)

## Overview
Collect service health across multiple Windows machines from a CSV list and report:
- Services with `StartMode = Auto` but `State != Running`

The script connects using CIM over **WinRM (WSMan)** by default and can optionally fall back to **DCOM**.

## Files
- `scripts/service_health.ps1`
- `data/computers.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- PowerShell 5.1+
- Network connectivity to targets
- Permissions to query services on target machines
- WinRM enabled on targets (recommended)

## WinRM quick setup (domain lab)
Run on each target (as Admin):
```powershell
Enable-PSRemoting -Force
```

From the collector machine, test:
```powershell
Test-WSMan -ComputerName <TARGET>
```

## CSV input
data/computers.template.csv
```csv
ComputerName
DC01-AZlab
CLIENT01
CLIENT02
```
