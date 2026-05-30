# PowerShell Lab Repository

A collection of hands-on PowerShell labs for **Systems Administrator / Infrastructure** skill building.

Each lab is self-contained under `labs/` with:
- scripts
- template data (public-safe)
- sample reports/output
- a dedicated `README.md` with instructions and evidence

> Note: This repo uses placeholders such as `example.local` in templates for general use.  
> In my personal lab environment, I run these labs in the `ryohei.azlab` domain.

---

## Repository Structure

```text
powershell-portfolio-lab/
  labs/
    01-ad-bulk-users/
    02-ad-group-management/
    03-ad-offboarding-soft-delete/
    04-win-service-health/
    05-win-local-admins-audit/
    06-win-software-inventory/
    07-win-security-logons-lockouts/
  shared/
    helpers/
      common.ps1
  README.md
  .gitignore
```

---

## Labs Index

### Active Directory
- **01-ad-bulk-users** *(completed)* — Bulk create/delete AD users from CSV (template-driven, existence checks, `-WhatIf` recommended). ([Lab README](labs/01-ad-bulk-users/README.md))
- **02-ad-group-management** *(completed)* — Bulk add/remove users to/from AD groups from CSV (reporting included). ([Lab README](labs/02-ad-group-management/README.md))
- **03-ad-offboarding-soft-delete** *(completed)* — Offboarding workflow: disable account + move to Disabled Users OU + optional group cleanup + reporting. ([Lab README](labs/03-ad-offboarding-soft-delete/README.md))

### Windows Operations
- **04-win-service-health** *(completed)* — Multi-machine service health reporting (Auto-start services not running) via CIM over WinRM + tuning. ([Lab README](labs/04-win-service-health/README.md))
- **05-win-local-admins-audit** *(completed)* — Multi-machine local Administrators audit via WinRM with localization-safe group resolution (SID-based). ([Lab README](labs/05-win-local-admins-audit/README.md))
- **06-win-software-inventory** *(completed)* — Multi-machine software inventory via WinRM using registry uninstall keys (HKLM x64 + WOW6432Node). ([Lab README](labs/06-win-software-inventory/README.md))
- **07-win-security-logons-lockouts** *(completed)* — Multi-machine Security log audit via WinRM (4625/4776/4771 failures + 4740 lockouts, DC included). ([Lab README](labs/07-win-security-logons-lockouts/README.md))
---

## Quick Start

```powershell
# Lab 04: service health
cd .\labs\04-win-service-health\
.\scripts\service_health.ps1 -ConnectivityOnly -Verbose
.\scripts\service_health.ps1 -Verbose
```

```powershell
# Lab 05: local admins audit
cd .\labs\05-win-local-admins-audit\
.\scripts\local_admins_audit.ps1 -ConnectivityOnly -Verbose
.\scripts\local_admins_audit.ps1 -Verbose
```

```powershell
# Lab 06: software inventory
cd .\labs\06-win-software-inventory\
.\scripts\software_inventory.ps1 -ConnectivityOnly -Verbose
.\scripts\software_inventory.ps1 -Verbose
```

---

## Requirements
Some labs require different permissions, but commonly:
- Windows PowerShell **5.1+** (or PowerShell 7+ depending on the lab)
- Admin privileges may be required for OS-level checks
- For AD labs: **RSAT / ActiveDirectory** module + domain permissions
- For multi-machine Windows labs: **WinRM** enabled and reachable on targets

---

## Public-Safe Data Policy
To avoid exposing real data:
- Use `*.template.csv` for examples
- Do not commit real passwords, tenant details, or production data
- Use `.gitignore` to block real CSVs and logs

---

## Reports Hygiene
Most labs generate timestamped outputs in `reports/`.
To keep the repo clean:
- Only `sample-*.csv` reports are committed
- Timestamped reports are ignored via each lab’s `reports/.gitignore`

---

## How to Use This Repo
1) Pick a lab under `labs/`  
2) Read the lab README  
3) Run the script(s) from that lab folder  
4) Check `reports/` and `screenshots/` (if included)

---

## Roadmap
Planned improvements across labs:
- Consistent reporting schema (Created/Skipped/Failed + reason + timestamp)
- Shared helper functions in `shared/helpers/common.ps1`
- More input validation and safer defaults (`-WhatIf`, soft delete patterns, clearer pre-flight checks)

---

## Disclaimer

Educational/lab use only. Always follow organizational security policies when handling identities and credentials.
