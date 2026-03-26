# Infrastructure & Detection as Code | CI/CD Pipeline

> A multi-environment Azure security pipeline built by a SOC analyst — automating the deployment of Microsoft Sentinel detection rules, Log Analytics Workspaces, and cloud security policy using GitHub Actions, ARM templates, and Bicep.

---

## What This Project Does

Rather than manually configuring Sentinel analytics rules, deploying workspaces, or enforcing cloud policy through the Azure Portal, this repository treats every security artefact as code. Every detection rule, every workspace, every policy is version-controlled, peer-reviewable, and deployed automatically through GitHub Actions pipelines.

This approach brings software engineering discipline to security operations — detections are auditable, deployments are repeatable, and environments stay consistent.

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy-detections.yml                        # Pipeline: deploy Sentinel analytics rules
│       ├── deploy-log-analytics-workspace-sentinel.yml  # Pipeline: deploy LAW + onboard Sentinel
│       └── deploy-policy.yml                            # Pipeline: deploy Azure Policy definitions
│
├── detections/
│   ├── Bunny-Loader-Malware.json                        # ARM: registry persistence detection
│   ├── Email-Containing-Suspicious-TLD.json             # ARM: phishing TLD detection with click enrichment
│   ├── Self-Assigned-User-Roles.json                    # ARM: privilege escalation detection
│   ├── Sign-In-From-Unusual-Location.json               # ARM: watchlist-driven geo anomaly detection
│   └── Unauthorised-Web-Browsers.json                   # ARM: unauthorised software detection
│
└── infrastructure/
    ├── Azure-Policy-as-Code/
    │   ├── Deny-Storage-Public-Blob-Access.json          # ARM: policy to block public blob access
    │   └── policy.md                                     # Annotated walkthrough of the policy template
    │
    └── Log-Analytics-Workspace-Sentinel/
        ├── Log-Analytics-Workspace.bicep                 # Bicep: provisions LAW and onboards Sentinel
        └── parameters/
            ├── client-a.bicepparam                       # Params: Client A workspace config
            └── client-b.bicepparam                       # Params: Client B workspace config
```

---

## GitHub Actions Workflows

All three workflows are triggered manually via `workflow_dispatch` and accept a `client` input that maps to a GitHub Environment. Each environment holds its own secrets and variables (Azure credentials, resource group name, workspace name, etc.), which allows the same workflow to deploy to multiple tenants without code changes.

### `deploy-detections.yml` — Deploy Sentinel Analytics Rules

Iterates over every `.json` file in the `/detections` folder and deploys each one as a Sentinel Scheduled Analytics Rule into the target workspace.

**Steps:**
1. Checks out the repository
2. Authenticates to Azure using a Service Principal stored in `AZURE_SP_CREDENTIALS`
3. Validates each ARM template against the target resource group (`az deployment group validate`)
4. Deploys each template using `az deployment group create`

The loop-based approach means new detections are automatically picked up without modifying the pipeline — drop a `.json` file in `/detections` and it deploys on the next run.

### `deploy-log-analytics-workspace-sentinel.yml` — Deploy LAW + Sentinel

Provisions a Log Analytics Workspace and onboards Microsoft Sentinel on top of it, using a Bicep template and a per-client parameter file.

**Steps:**
1. Checks out the repository
2. Authenticates to Azure
3. Deploys the Bicep template with the client-specific parameter file (e.g. `client-a.bicepparam`)

### `deploy-policy.yml` — Deploy Azure Policy

Iterates over every `.json` file in `/infrastructure/Azure-Policy-as-Code/` and deploys each one as a subscription-scoped Azure Policy definition.

**Steps:**
1. Checks out the repository
2. Authenticates to Azure
3. Validates each ARM template at subscription scope (`az deployment sub validate`)
4. Deploys each template using `az deployment sub create`

---

## Detection Rules (`/detections`)

Each detection is an ARM template that deploys a Scheduled Analytics Rule into Microsoft Sentinel. All rules use `guid(parameters('workspace'), '<unique-string>')` for stable, idempotent rule IDs — the same workspace and seed string always produce the same GUID, preventing duplicates on redeployment.

### Bunny Loader Malware (`Bunny-Loader-Malware.json`)

**MITRE:** Persistence — T1037.001 (Boot or Logon Initialization Scripts: Logon Scripts)

Targets the `DeviceRegistryEvents` table to detect processes writing to Windows Run/RunOnce registry keys where the value points to a suspicious execution path — `AppData`, `Temp`, `ProgramData`, or common LOLBin interpreters (`powershell`, `cmd.exe`, `wscript`, `mshta`). This pattern is consistent with how Bunny Loader establishes persistence on a host.

### Email Containing Suspicious TLD (`Email-Containing-Suspicious-TLD.json`)

**MITRE:** Initial Access

Searches `EmailUrlInfo` for emails containing URLs with high-abuse TLDs (`.zip`, `.mov`, `.cfd`, `.quest`, `.cam`, etc.), then enriches results with metadata from `EmailEvents` and click data from `UrlClickEvents`. Includes false-positive tuning via a `knownSenders` exclusion list, filters to delivered mail only, excludes on-premises relay duplicates, and parses SPF/DKIM/DMARC authentication results into discrete columns.

### Self-Assigned User Roles (`Self-Assigned-User-Roles.json`)

**MITRE:** Privilege Escalation — T1078.004 (Valid Accounts: Cloud Accounts)

Queries `AuditLogs` for successful `Add member to role` operations where the initiating user and the target user are the same principal — a strong indicator of privilege self-escalation. Includes entity mapping for the account and the role name, and filters out events where user fields fail to parse (a common source of false positives in this table).

### Sign-In From Unusual Location (`Sign-In-From-Unusual-Location.json`)

**MITRE:** Initial Access — T1078 (Valid Accounts)

Builds a dynamic lookup of each user's last known successful sign-in country from the past 30 days using a Sentinel Watchlist (`knownLocations`), then alerts on successful sign-ins from countries not in that list. Outputs authentication context including MFA requirement, Conditional Access status, and client app type to support fast triage.

### Unauthorised Web Browsers (`Unauthorised-Web-Browsers.json`)

**MITRE:** Defense Evasion

Detects the execution of browsers not approved by your organisation across three MDE tables — `DeviceProcessEvents`, `DeviceEvents`, and `DeviceNetworkEvents` — then unions the results and summarises by device and account with first/last seen timestamps and an event count. Dual-table process coverage reduces evasion via unusual launch paths.

---

## Infrastructure (`/infrastructure`)

### Log Analytics Workspace + Sentinel (`Log-Analytics-Workspace.bicep`)

A Bicep template that creates a Log Analytics Workspace and immediately onboards Microsoft Sentinel onto it in a single deployment.

**Parameters:**

| Parameter | Description |
|---|---|
| `logAnalyticsWorkspaceName` | Name of the workspace |
| `location` | Azure region (inherits from resource group) |
| `retentionDays` | Log retention period (30–730 days) |
| `SKU` | Pricing tier (`PerGB2018`, `Free`, `CapacityReservation`, etc.) |

**Per-client parameter files** in `/parameters/` allow the same Bicep template to deploy differently per client without any code changes:

- `client-a.bicepparam` — 90-day retention, PerGB2018 tier
- `client-b.bicepparam` — 90-day retention, Free tier

Outputs the workspace ID and name to the deployment log for downstream reference.

### Azure Policy — Deny Public Blob Access (`Deny-Storage-Public-Blob-Access.json`)

A subscription-scoped ARM template that defines a custom Azure Policy targeting `Microsoft.Storage/storageAccounts`. The policy fires when `allowBlobPublicAccess` is either explicitly set to `true` or the property is absent entirely (the unsafe default in older API versions).

The `policyEffect` parameter is configurable at deployment time — `Audit` in non-production to assess exposure, `Deny` in production to block non-compliant deployments outright. This allows the same definition to be rolled out progressively without editing the template.

`policy.md` provides a fully annotated walkthrough of the ARM template format, the distinction between ARM parameters and policy parameters, and the reasoning behind each design decision.

---

## Multi-Client Architecture

GitHub Environments are used to scope secrets and variables per client. When a workflow is triggered, the `client` input selects the target environment, and all subsequent steps pull credentials and configuration from that environment's context. No credentials or environment-specific values are hardcoded anywhere in the repository.

```
GitHub Repository
├── Environment: client-a
│   ├── Secret: AZURE_SP_CREDENTIALS  → Service Principal for Client A's tenant
│   ├── Var: AZURE_RESOURCE_GROUP     → Client A's resource group
│   └── Var: AZURE_WORKSPACE          → Client A's Sentinel workspace name
│
└── Environment: client-b
    ├── Secret: AZURE_SP_CREDENTIALS  → Service Principal for Client B's tenant
    ├── Var: AZURE_RESOURCE_GROUP     → Client B's resource group
    └── Var: AZURE_WORKSPACE          → Client B's Sentinel workspace name
```

---

## Tech Stack

| Technology | Role |
|---|---|
| GitHub Actions | Pipeline orchestration and environment management |
| Azure Bicep | Infrastructure as Code (Log Analytics Workspace + Sentinel) |
| ARM Templates | Detection as Code (Sentinel analytics rules) and Policy as Code |
| Microsoft Sentinel | Target SIEM — analytics rules deployed here |
| Azure Policy | Preventive cloud security control at subscription scope |
| Azure CLI (`az`) | Deployment engine called within pipeline steps |
| KQL | Query language powering all detection logic |

---

## Design Decisions & Lessons Learned

**Stable rule GUIDs via `guid()`**

Early deployments failed when attempting to redeploy a rule whose ID had been recently deleted from Sentinel — Azure retains deleted resource IDs briefly. The fix was replacing hardcoded GUIDs with `guid(parameters('workspace'), '<seed-string>')`, which produces a deterministic GUID from the workspace name and a unique seed. The same inputs always produce the same ID, so redeployments are idempotent and there are no duplicate rules.

**Validation before deployment**

Both detection and policy pipelines run an explicit `validate` step before `create`. This catches ARM schema errors and permission issues before any changes are made to the target environment.

**Loop-based deployment**

Using `for file in detections/*.json` means the pipeline is self-maintaining — adding a new detection or policy requires only dropping a file into the right folder. The workflow never needs to be edited.

**Parameterised effect in policy definitions**

Defaulting the `policyEffect` to `Audit` means deploying to an existing environment is always safe on first run — it will surface non-compliant resources without blocking anything. Switching to `Deny` is a deliberate, explicit step.

---

## About

This project was built to demonstrate that SOC detection engineering and cloud infrastructure work are not separate disciplines. Detection rules are code. Infrastructure is code. Both belong in version control, both benefit from automated deployment pipelines, and both should be treated with the same rigour as application development.

The repository is actively maintained and will grow to include additional detections, Bicep modules, and pipeline improvements over time.
