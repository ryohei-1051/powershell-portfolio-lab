# Reflection: PowerShell Portfolio (Labs 01–09)

Purpose: consolidate the PowerShell patterns I used across Labs 01–09 into reusable skills for:
- real ops work (repeatable, safe, observable)
- interviews (clear explanation + verification)
- LinkedIn posts (topic-based mini-lessons tied to repo evidence)

> Evidence lives in each lab folder (scripts/templates/sample reports/screenshots).  
> This reflection is topic-based, with a mapping to the labs where each topic appears.

---

## Topic → Lab Mapping

| Topic | Labs |
|------|------|
| CSV-driven automation + reporting patterns | 01, 02, 03, 04, 05, 06, 07, 08, 09 |
| Active Directory lifecycle (users) | 01, 03 |
| Active Directory group operations | 02, 03 |
| WinRM + remoting patterns (Invoke-Command / CIM) | 04, 05, 06, 07, 08, 09 |
| Service health monitoring | 04 |
| Local Administrators audit | 05 |
| Software inventory (registry uninstall keys) | 06 |
| Security events: failures + lockouts (4625/4776/4771/4740) | 07 |
| Health snapshot (disk + uptime + critical services) | 08 |
| Patch + pending reboot readiness | 09 |
| Repo hygiene: templates/samples/ignore rules/releases | all |

---

## How I Use This Reflection

- When I forget a pattern → check “Key commands” + “Verification checklist.”
- When I get stuck → check “Failure modes I hit” + “Fix / diagnostic commands.”
- When I write LinkedIn posts → use the “LinkedIn post angle” block under each topic.

---

## Topic 1 — CSV-driven automation + reporting patterns

### What this topic covers
Turning a CSV into repeatable operations with:
- input validation
- “safe mode” (e.g., `-WhatIf` or read-only)
- structured outputs (status + detail)
- predictable file paths and sample outputs

### Key commands / patterns
- `Import-Csv` → pipeline input
- `Join-Path $PSScriptRoot ...` → repo-relative paths
- `Resolve-Path` + clear error messages → fail fast on missing files
- `try/catch` per target or per row → partial success without losing the whole run
- `Export-Csv -NoTypeInformation` → machine-readable evidence

### Failure modes I hit (and what fixed them)
- Relative path failures when running from different folders  
  → use `Join-Path $PSScriptRoot` and allow `-CsvPath` override
- Empty output files  
  → confirm I’m returning objects (not swallowing output), and validate counts
- “Success but blank fields”  
  → add guard: `if (-not $result) { throw "No data returned" }`

### Verification checklist (portable)
- Confirm CSV is found:
  - `Resolve-Path .\data\<file>.csv`
- Confirm rows imported:
  - `(Import-Csv .\data\<file>.csv | Measure-Object).Count`
- Confirm outputs:
  - `Get-ChildItem .\reports | Sort LastWriteTime -Desc | Select -First 5`

### LinkedIn post angle
**Hook:** “CSV-driven automation isn’t the script — it’s the safety + reporting.”  
**Show:** 1 screenshot of run output + 1 screenshot of a sample report.  
**Bullet points:** input validation, per-target status, sample reports committed, timestamp spam ignored.

---

## Topic 2 — Active Directory lifecycle automation (Users)

### What this topic covers
Creating/deleting users from CSV safely and repeatably.

### Key commands / patterns
- `Import-Module ActiveDirectory`
- `Get-ADUser` / `Get-ADObject` checks before create/delete
- `New-ADUser` / `Remove-ADUser` with existence checks
- `-WhatIf` and/or “dry run” behavior where applicable

### Failure modes I hit
- Using display name vs `SamAccountName` confusion  
  → standardize on `SamAccountName` in CSV and checks
- OU DN mismatch across environments  
  → use templates with placeholders + clear README notes

### Verification checklist
- Confirm user exists:
  - `Get-ADUser -Identity <sam>`
- Confirm deletion:
  - `Get-ADUser -Filter "SamAccountName -eq '<sam>'"`

### LinkedIn post angle
**Hook:** “Bulk AD user management without guardrails is how mistakes happen.”  
**Bullets:** template CSV, existence checks, `-WhatIf`, report counts.

---

## Topic 3 — Active Directory group operations (membership + offboarding cleanup)

### What this topic covers
Bulk add/remove membership and optional cleanup during offboarding.

### Key commands / patterns
- `Get-ADGroup`, `Get-ADUser` existence checks
- `Add-ADGroupMember`, `Remove-ADGroupMember`
- “Why group cleanup can look wrong”: primary groups / replication / membership refresh timing

### Failure modes I hit
- “Group not found” because group didn’t exist → add a setup script or create test groups
- Membership appears unchanged immediately → re-check, replication timing, and confirm group queries

### Verification checklist
- Confirm membership:
  - `Get-ADPrincipalGroupMembership <user> | Select Name`

### LinkedIn post angle
**Hook:** “Group automation is easy. Making it reliable is the work.”  
**Show:** one failed run → one fixed run (setup_groups + re-run).

---

## Topic 4 — WinRM / Remoting patterns (CIM vs Invoke-Command)

### What this topic covers
Two approaches across my labs:
- CIM queries over WinRM (WSMan): `Get-CimInstance`, CimSession
- PowerShell Remoting: `Invoke-Command`

### Key commands / patterns
- `Test-WSMan <target>` preflight
- `Invoke-Command -ArgumentList ...` for passing target/context
- Use `Target` (FQDN from CSV) + `ComputerName` (hostname) in outputs for correlation
- “ConnectivityOnly” mode: validate access before full collection

### Failure modes I hit
- `$sb` null in interactive shell (expected) → define it in script; don’t rely on console
- “Success but no data” → add guard: `if (-not $result) { throw ... }`

### Verification checklist
- `Test-WSMan <host>`
- `Resolve-DnsName <host>`
- Run ConnectivityOnly first, then full run

### LinkedIn post angle
**Hook:** “Most ‘remote scripts’ fail because of preflight, not logic.”  
**Show:** connectivity-only report + full report.

---

## Topic 5 — Service health monitoring (Auto-start not running)

### Key idea
Detect signal, then tune noise (include/exclude).

### LinkedIn post angle
**Hook:** “Not every stopped auto service is a problem — but it’s always a signal.”

---

## Topic 6 — Local Administrators audit

### Key idea
Use SID-safe resolution and report correlation fields.

### LinkedIn post angle
**Hook:** “Local admin visibility is one of the fastest security wins.”

---

## Topic 7 — Software inventory (registry uninstall keys)

### Key idea
Avoid `Win32_Product`; registry + clear limitations (HKLM vs HKCU).

### LinkedIn post angle
**Hook:** “Inventory is not compliance — it’s visibility with known blind spots.”

---

## Topic 8 — Security events: failures + lockouts

### Key idea
4625 is not guaranteed on DC; 4776/4771 are often the real signals depending on auth path. Include DC for 4740.

### LinkedIn post angle
**Hook:** “In domain labs, ‘failed logon’ often shows up as 4776, not 4625.”

---

## Topic 9 — Health snapshot (disk + uptime + critical services from CSV)

### Key idea
Health snapshots are “ops dashboards” — define what matters via service list CSV.

### LinkedIn post angle
**Hook:** “A good health check is configurable without editing code.”

---

## Topic 10 — Patch + Pending Reboot readiness

### Key idea
Pending reboot signals are multi-source (CBS/WU/Session Manager). Treat hotfix date as signal, not full compliance.

### LinkedIn post angle
**Hook:** “Pending reboot is a change-management signal, not just a checkbox.”

---

## Repo hygiene checklist (what makes this portfolio credible)
- Templates: `*.template.csv` only
- Sample outputs committed: `sample-*.csv`
- Timestamp outputs ignored: `reports/.gitignore`
- Evidence screenshots in each lab
- Release tag notes summarize scope (v1.1)

---

## LinkedIn series plan (topic-based)
I can turn this reflection into a short series:

1) CSV-driven automation + reporting (pattern used in every lab)
2) WinRM preflight + correlation fields (Target vs ComputerName)
3) Inventory & audit patterns (local admins + software inventory)
4) Security signals (4776/4740) + why DC matters
5) Ops dashboards (health snapshot + patch/reboot readiness)

Each post:
- 1 hook line
- 3–5 bullets
- “Repo pinned in Featured”
- optional: 1 screenshot (report or terminal output)
