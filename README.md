# PowerShell Lab Repository (BCIT)

This repository is a collection of hands-on PowerShell labs for Systems Administrator / Infrastructure skill building.

Each lab is self-contained under `labs/` with:
- scripts
- template data (public-safe)
- sample reports/output
- a dedicated `README.md` with instructions

> Note: This repo uses placeholders such as `example.local` in templates for general use.  
> In my personal lab environment, I run these labs in the `ryohei.lab` domain.

---

## Repository Structure

```text
powershell-lab/
  labs/
    01-ad-bulk-users/
      scripts/
      data/
      reports/
      screenshots/
      README.md
    02-ad-group-management/
    03-ad-offboarding-soft-delete/
    04-win-service-health/
    05-win-local-admins-audit/
    06-win-software-inventory/
  shared/
    helpers/
      common.ps1
  README.md
  .gitignore

## Labs Index

### Active Directory
- **01-ad-bulk-users**  
  Bulk create/delete AD users from CSV (template-driven, existence checks, `-WhatIf` recommended)

- **02-ad-group-management** *(planned)*  
  Bulk add/remove users to/from AD groups (CSV-driven)

- **03-ad-offboarding-soft-delete** *(planned)*  
  Offboarding workflow: disable account + move OU + optional group cleanup + reporting

### Windows Operations
- **04-win-service-health** *(planned)*  
  Report stopped services that should be running (StartType=Automatic)

- **05-win-local-admins-audit** *(planned)*  
  Audit Local Administrators group membership

- **06-win-software-inventory** *(planned)*  
  Export installed software inventory (local first; remote later)

Each lab has its own README: `labs/<lab-name>/README.md`

---

## Requirements

Some labs require different permissions, but commonly:
- Windows PowerShell **5.1+** (or PowerShell 7+ depending on the lab)
- Admin privileges may be required for OS-level checks
- For AD labs: **RSAT / ActiveDirectory** module + domain permissions

---

## Public-Safe Data Policy

To avoid exposing real data:
- Use `*.template.csv` for examples
- Do not commit real passwords, tenant details, or production data
- Use `.gitignore` to block real CSVs and logs

---

## How to Use This Repo

1) Pick a lab under `labs/`  
2) Read the lab README  
3) Run the script(s) from that lab folder  
4) Check `reports/` and `screenshots/` (if included)

---

## Roadmap

Planned improvements across labs:
- Consistent reporting (CSV output: Created/Skipped/Failed + reason + timestamp)
- Shared helper functions in `shared/helpers/common.ps1`
- More input validation and safer defaults (`-WhatIf`, soft delete, etc.)

---

## Disclaimer

Educational/lab use only. Always follow organizational security policies when handling identities and credentials.

---

## What to Do Next

1) Move your current files into:
- `labs/01-ad-bulk-users/scripts/`
- `labs/01-ad-bulk-users/data/`

2) Put your current detailed instructions into:
- `labs/01-ad-bulk-users/README.md`

3) Keep the root `README.md` as the index above.
