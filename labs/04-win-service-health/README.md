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
`data/computers.template.csv`

```csv
ComputerName
CLIENT1.ryohei.azlab
Lab4Server.ryohei.azlab
```

## Run
From the lab folder:

```powershell
cd .\labs\04-win-service-health\
```
# 1) Connectivity-only (WinRM/CIM session validation)
.\scripts\service_health.ps1 -ConnectivityOnly -Verbose

# 2) Full run (collect Win32_Service + export reports)
.\scripts\service_health.ps1 -Verbose

## Notes
- `-ConnectivityOnly` validates connectivity and exports the status report.
The issues report may be empty because service collection is skipped.

## Interpretation (important)
This lab reports services where `StartMode = Auto` but `State != Running`.
Not every result indicates an incident:
- Some services are **Delayed Auto Start** or **trigger-start** in practice
- Some services (e.g., `RemoteRegistry`) may be intentionally stopped/disabled by policy

Treat the issues report as a starting point for validation, not an automatic “fix list”.

## Tuning / Reducing Noise
You can exclude known “expected” services in your environment.

Example:
```powershell
.\scripts\service_health.ps1 -Verbose `
  -ExcludeName AppXSvc,DoSvc,edgeupdate,MapsBroker,sppsvc,RemoteRegistry
```
Or focus on only specific services:
```powershell
.\scripts\service_health.ps1 -Verbose `
  -IncludeName w32time,WinRM
```

## Output
Two CSV reports are generated in `reports/`:
- `service_issues_YYYYMMDD_HHMMSS.csv`
- `computer_status_YYYYMMDD_HHMMSS.csv`

## Evidence (screenshots)
- Script run output showing both report paths
- Opened `computer_status_*.csv` showing per-host success + issue counts
- Opened `service_issues_*.csv` showing detected services
