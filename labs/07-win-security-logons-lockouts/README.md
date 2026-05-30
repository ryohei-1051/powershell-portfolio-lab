# Lab 07: Security Logons / Lockouts (Multi-machine)

## Overview
Collect Windows Security events across multiple machines from a CSV list using WinRM (PowerShell Remoting).

Focused events:
- **4625** Failed logon
- **4776** NTLM credential validation failed (common for your `net use` test)
- **4771** Kerberos pre-authentication failed (depends on test method)
- **4740** Account lockout (typically logged on Domain Controllers)

## Files
- `scripts/security_logons_lockouts.ps1`
- `data/computers.template.csv`
- `reports/` (output)
- `screenshots/` (evidence)

## Requirements
- PowerShell 5.1+
- Network connectivity to targets
- WinRM enabled on targets
- Permissions to read Security logs (local admin or Event Log Readers)

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
DC01-AZlab.ryohei.azlab
CLIENT1.ryohei.azlab
Lab4Server.ryohei.azlab
```
## Run
From the lab folder:
```powershell
cd .\labs\07-win-security-logons-lockouts\

# Connectivity-only
.\scripts\security_logons_lockouts.ps1 -ConnectivityOnly -Verbose

# Full run (default: last 1 day)
.\scripts\security_logons_lockouts.ps1 -Verbose
```
## Optional settings
```powershell
# Last 7 days, limit 200 events per host
.\scripts\security_logons_lockouts.ps1 -DaysBack 7 -MaxEventsPerHost 200 -Verbose

# Include successful logons (4624)
.\scripts\security_logons_lockouts.ps1 -IncludeSuccessLogons -Verbose
```

## Output
Three CSV reports are generated in `reports/`:
- `computer_status_YYYYMMDD_HHMMSS.csv`
- `security_events_YYYYMMDD_HHMMSS.csv`
- `security_summary_YYYYMMDD_HHMMSS.csv`

## Interpretation
- Not every 4625 is an attack; some are misconfigurations (bad password, stale credentials, service accounts).
- Lockout events (4740) are most useful on Domain Controllers.
- Treat this as a visibility + triage tool.

## Evidence (screenshots)
- Script run output showing report paths
- Opened `computer_status_*.csv`
- Opened `security_summary_*.csv` (counts by user/source)


---

## Evidence plan (screenshots-only is fine)
Capture:
1) run output (“Events report saved…”)
2) `computer_status_*.csv` opened
3) `security_summary_*.csv` opened

---
