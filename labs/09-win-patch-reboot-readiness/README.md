# Lab 09: Patch + Pending Reboot Readiness (Multi-machine)

## Overview
Collect patch and reboot readiness signals across multiple Windows machines from a CSV list using WinRM:
- Last boot time + uptime
- Latest hotfix install date (and KB list)
- Pending reboot indicators (common registry/CBS/WU signals)

## Files
- `scripts/patch_reboot_readiness.ps1`
- `data/computers.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- PowerShell 5.1+
- WinRM enabled on targets
- Permissions to query CIM + registry on targets (local admin is safest)

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
cd .\labs\09-win-patch-reboot-readiness\

# Connectivity-only
.\scripts\patch_reboot_readiness.ps1 -ConnectivityOnly -Verbose

# Full run
.\scripts\patch_reboot_readiness.ps1 -Verbose
```

### Optional: run with explicit credentials

```powershell
$cred = Get-Credential
.\scripts\patch_reboot_readiness.ps1 -Credential $cred -Verbose
```

## Output

Two CSV reports are generated in `reports/`:

- `computer_status_YYYYMMDD_HHMMSS.csv`
- `patch_reboot_readiness_YYYYMMDD_HHMMSS.csv`

## Interpretation
- `PendingReboot=True` is a change/maintenance signal (often after updates or driver installs).
- Hotfix history varies by OS build; treat `LatestHotfixDate` as a signal, not a full patch compliance solution.

## Evidence (screenshots)
- Script run output showing report paths
- Opened `computer_status_*.csv`
- Opened `patch_reboot_readiness_*.csv`
