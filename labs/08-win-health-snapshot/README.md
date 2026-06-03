# Lab 08: Windows Health Snapshot (Multi-machine)

## Overview
Collect a health snapshot across multiple Windows machines from a CSV list using WinRM:
- Disk usage (fixed drives)
- Last boot time + uptime
- Critical services status (service list from CSV)

## Files
- `scripts/health_snapshot.ps1`
- `data/computers.template.csv`
- `data/services.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- PowerShell 5.1+
- WinRM enabled on targets
- Permissions to query CIM + services on targets (local admin is safest)

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

`data/services.template.csv`

```csv
ServiceName,Note
WinRM,Remote management
W32Time,Time sync
EventLog,Windows Event Log
LanmanServer,File/print server (Server OS)
```

## Run

From the lab folder:
```powershell
cd .\labs\08-win-health-snapshot\

# Connectivity-only
.\scripts\health_snapshot.ps1 -ConnectivityOnly -Verbose

# Full snapshot
.\scripts\health_snapshot.ps1 -Verbose
```

### Optional: run with explicit credentials

```powershell
$cred = Get-Credential
.\scripts\health_snapshot.ps1 -Credential $cred -Verbose
```

## Output
Three CSV reports are generated in `reports/`:

- `computer_status_YYYYMMDD_HHMMSS.csv`
- `disk_usage_YYYYMMDD_HHMMSS.csv`
- `critical_services_YYYYMMDD_HHMMSS.csv`

### Interpretation
- A stopped service is not always a problem; verify expected state for your environment.
- Disk FreePct is a good quick signal for capacity issues.

### Evidence (screenshots)
- Script run output showing report paths
- Opened `computer_status_*.csv`
- Opened `disk_usage_*.csv`
- Opened `critical_services_*.csv`

