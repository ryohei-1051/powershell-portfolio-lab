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
```

From the collector machine, test:
```powershell
Test-WSMan -ComputerName <TARGET>
```

## CSV input
`data/computers.template.csv`

```powershell
ComputerName
CLIENT1.ryohei.azlab
Lab4Server.ryohei.azlab
```

## Run
From the lab folder:
```powershell
cd .\labs\05-win-local-admins-audit\

# 1) Connectivity-only (validate WinRM access)
.\scripts\local_admins_audit.ps1 -ConnectivityOnly -Verbose

# 2) Full run (collect local admins membership)
.\scripts\local_admins_audit.ps1 -Verbose
```
# Optional: run with explicit credentials
```powershell
$cred = Get-Credential
.\scripts\local_admins_audit.ps1 -Credential $cred -Verbose
```

## Output
Two CSV reports are generated in `reports/`:
- `local_admins_members_YYYYMMDD_HHMMSS.csv`
- `computer_status_YYYYMMDD_HHMMSS.csv`

## Report fields (high level)
- `computer_status_*.csv` includes: `ComputerName` (target), `Hostname`, `MembersCount`, and error details if failed
- `local_admins_members_*.csv` includes both:
  - `Target` (value from CSV, e.g., FQDN)
  - `ComputerName` (remote hostname)

## Interpretation
This is an audit report. Review entries carefully:
- Domain groups nested into local Administrators may appear as a single entry (group name)
- A domain admin group appearing in local Administrators may be normal in labs but should be justified/reviewed in production

## Evidence (screenshots)
- Script run output showing both report paths
- Opened `computer_status_*.csv`
- Opened `local_admins_members_*.csv`
