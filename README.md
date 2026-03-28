# Infrastructure & Detection as Code | CI/CD Pipeline

> A multi-environment Azure security pipeline built by a SOC analyst — automating the deployment of Microsoft Sentinel detection rules, Log Analytics Workspaces, Entra ID diagnostic settings, and cloud security policy using GitHub Actions, ARM templates, and Bicep.

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
│       ├── deploy-detections.yml                        # Pipeline: validate and deploy Sentinel analytics rules
│       ├── deploy-log-analytics-workspace-sentinel.yml  # Pipeline: deploy LAW + onboard Sentinel
│       ├── deploy-policy.yml                            # Pipeline: validate and deploy Azure Policy definitions
│       └── deploy-entra-id-logs.yml                     # Pipeline: deploy Entra ID diagnostic settings
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
    ├── Log-Analytics-Workspace-Sentinel/
    │   ├── Log-Analytics-Workspace.bicep                 # Bicep: provisions LAW and onboards Sentinel
    │   └── parameters/
    │       ├── client-a.bicepparam                       # Params: Client A workspace config
    │       └── client-b.bicepparam                       # Params: Client B workspace config
    │
    └── Logs/
        └── Entra-ID-Logs.bicep                           # Bicep: configures Entra ID diagnostic settings
```

---

## Authentication — OIDC (No Stored Credentials)

All four pipelines authenticate to Azure using **OpenID Connect (OIDC)** via the `azure/login` action. No client secrets or service principal credentials are stored anywhere in the repository or in GitHub Secrets.

Each job requests a short-lived identity token from GitHub at runtime:

```yaml
permissions:
  id-token: write   # Required for OIDC — tells GitHub to mint a token for this job
  contents: read
```

Azure verifies the token against a federated credential configured on the App Registration, confirming the request is genuinely coming from this repository and environment before granting access. The token expires when the job ends.

The three values used in the login step are non-sensitive identifiers — not secrets — and are stored as GitHub Environment variables:

```yaml
- name: Login to Azure
  uses: azure/login@v3
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

This means there are no stored credentials that can be leaked, rotated, or expire unexpectedly.

---

## GitHub Actions Workflows

All four workflows are triggered manually via `workflow_dispatch` and accept a `client` input that maps to a GitHub Environment. Each environment holds its own variables (Azure identifiers, resource group name, workspace name, etc.), which allows the same workflow to deploy to multiple tenants without code changes.

### `deploy-detections.yml` — Deploy Sentinel Analytics Rules

Validates then deploys every `.json` file in `/detections` as a Sentinel Scheduled Analytics Rule into the target workspace.

**Steps:**
1. Accepts a `client` input matching a GitHub Environment name
2. Checks out the repository
3. Authenticates to Azure using OIDC
4. **Validates** each ARM template against the target resource group (`az deployment group validate`) — if any file fails, the pipeline stops and nothing is deployed
5. **Deploys** each validated template using `az deployment group create`

The validate-before-deploy pattern means schema errors and permission issues are caught before any changes reach the environment. The loop-based approach means new detections are automatically picked up without modifying the pipeline — drop a `.json` file into `/detections` and it deploys on the next run.

### `deploy-log-analytics-workspace-sentinel.yml` — Deploy LAW + Sentinel

Provisions a Log Analytics Workspace and onboards Microsoft Sentinel on top of it, using a Bicep template and a per-client parameter file.

**Steps:**
1. Accepts a `client` input matching a GitHub Environment name
2. Checks out the repository
3. Authenticates to Azure using OIDC
4. Deploys the Bicep template with the client-specific parameter file (e.g. `client-a.bicepparam`)

### `deploy-policy.yml` — Deploy Azure Policy

Validates then deploys every `.json` file in `/infrastructure/Azure-Policy-as-Code/` as a subscription-scoped Azure Policy definition.

**Steps:**
1. Accepts a `client` input matching a GitHub Environment name
2. Checks out the repository
3. Authenticates to Azure using OIDC
4. **Validates** each ARM template at subscription scope (`az deployment sub validate`) — if any file fails, the pipeline stops
5. **Deploys** each validated template using `az deployment sub create`

### `deploy-entra-id-logs.yml` — Deploy Entra ID Diagnostic Settings

Deploys the Entra ID diagnostic settings Bicep template at tenant scope, routing log categories into the target Log Analytics Workspace.

**Steps:**
1. Accepts a `client` input matching a GitHub Environment name
2. Checks out the repository
3. Authenticates to Azure using OIDC with `allow-no-subscriptions: true` (required for tenant-scoped deployments)
4. Deploys the Bicep template at tenant scope using `az deployment tenant create`

---

## Detection Rules (`/detections`)

Each detection is an ARM template that deploys a Scheduled Analytics Rule into Microsoft Sentinel. All rules use `guid(parameters('workspace'), '<unique-string>')` for stable, idempotent rule IDs — the same workspace and seed string always produce the same GUID, preventing duplicates on redeployment.

### Bunny Loader Malware (`Bunny-Loader-Malware.json`)

**MITRE:** Persistence — T1547.001 (Boot or Logon Autostart: Registry Run Keys)

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

**MITRE:** Defense Evasion — T1564

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

Per-client parameter files in `/parameters/` allow the same Bicep template to deploy differently per client without any code changes:

- `client-a.bicepparam` — 90-day retention, PerGB2018 tier
- `client-b.bicepparam` — 90-day retention, Free tier

### Entra ID Diagnostic Settings (`Entra-ID-Logs.bicep`)

A Bicep template deployed at tenant scope that routes Entra ID log categories into the target Log Analytics Workspace. Requires `allow-no-subscriptions: true` on the OIDC login step since the deployment operates above subscription level.

### Azure Policy — Deny Public Blob Access (`Deny-Storage-Public-Blob-Access.json`)

A subscription-scoped ARM template that defines a custom Azure Policy targeting `Microsoft.Storage/storageAccounts`. The policy fires when `allowBlobPublicAccess` is either explicitly set to `true` or the property is absent entirely (the unsafe default in older API versions).

The `policyEffect` parameter is configurable at deployment time — `Audit` in non-production to assess exposure, `Deny` in production to block non-compliant deployments outright. This allows the same definition to be rolled out progressively without editing the template.

`policy.md` provides a fully annotated walkthrough of the ARM template format, the distinction between ARM parameters and policy parameters, and the reasoning behind each design decision.

---

## Multi-Client Architecture

GitHub Environments are used to scope variables per client. When a workflow is triggered, the `client` input selects the target environment, and all subsequent steps pull configuration from that environment's context. No credentials or environment-specific values are hardcoded anywhere in the repository.

```
GitHub Repository
├── Environment: client-a
│   ├── Var: AZURE_CLIENT_ID          → App Registration client ID for Client A
│   ├── Var: AZURE_TENANT_ID          → Client A's Entra ID tenant ID
│   ├── Var: AZURE_SUBSCRIPTION_ID    → Client A's subscription ID
│   ├── Var: AZURE_RESOURCE_GROUP     → Client A's resource group
│   ├── Var: AZURE_WORKSPACE          → Client A's Sentinel workspace name
│   └── Var: AZURE_LOCATION           → Client A's Azure region
│
└── Environment: client-b
    ├── Var: AZURE_CLIENT_ID          → App Registration client ID for Client B
    ├── Var: AZURE_TENANT_ID          → Client B's Entra ID tenant ID
    ├── Var: AZURE_SUBSCRIPTION_ID    → Client B's subscription ID
    ├── Var: AZURE_RESOURCE_GROUP     → Client B's resource group
    ├── Var: AZURE_WORKSPACE          → Client B's Sentinel workspace name
    └── Var: AZURE_LOCATION           → Client B's Azure region
```

None of these are secrets — they are non-sensitive identifiers. There are no stored passwords, client secrets, or credentials anywhere in this repository.

---

## Tech Stack

| Technology | Role |
|---|---|
| GitHub Actions | Pipeline orchestration and environment management |
| Azure Bicep | Infrastructure as Code (Log Analytics Workspace, Sentinel, Entra ID logs) |
| ARM Templates | Detection as Code (Sentinel analytics rules) and Policy as Code |
| Microsoft Sentinel | Target SIEM — analytics rules deployed here |
| Azure Policy | Preventive cloud security control at subscription scope |
| Azure CLI (`az`) | Deployment engine called within pipeline steps |
| KQL | Query language powering all detection logic |
| OIDC | Credential-free authentication — no stored secrets anywhere |

---

## Design Decisions & Lessons Learned

**OIDC over Service Principal credentials**

All pipelines authenticate using OpenID Connect rather than a stored client secret. GitHub mints a short-lived identity token per job run; Azure verifies it against a federated credential on the App Registration. There is no secret to store, rotate, or leak. This is the correct approach for any pipeline touching production security infrastructure.

**Stable rule GUIDs via `guid()`**

Early deployments failed when attempting to redeploy a rule whose ID had been recently deleted from Sentinel — Azure retains deleted resource IDs briefly. The fix was replacing hardcoded GUIDs with `guid(parameters('workspace'), '<seed-string>')`, which produces a deterministic GUID from the workspace name and a unique seed. The same inputs always produce the same ID, so redeployments are idempotent and there are no duplicate rules.

**Validation before deployment**

The detection and policy pipelines both run an explicit `validate` step before `create`. This catches ARM schema errors and permission issues before any changes are made to the target environment. If validation fails, the deploy step never runs — the pipeline stops cleanly with the error surfaced in the logs.

**Loop-based deployment**

Using `for file in detections/*.json` means the pipeline is self-maintaining — adding a new detection or policy requires only dropping a file into the right folder. The workflow never needs to be edited.

**Parameterised effect in policy definitions**

Defaulting the `policyEffect` to `Audit` means deploying to an existing environment is always safe on first run — it will surface non-compliant resources without blocking anything. Switching to `Deny` is a deliberate, explicit step.

**Tenant-scoped Entra ID log deployment**

Configuring Entra ID diagnostic settings requires deploying at tenant scope rather than resource group or subscription scope. The OIDC login step uses `allow-no-subscriptions: true` to permit this, and the deployment uses `az deployment tenant create` rather than the resource group equivalent.

---

## About

This project was built to demonstrate that SOC detection engineering and cloud infrastructure work are not separate disciplines. Detection rules are code. Infrastructure is code. Both belong in version control, both benefit from automated deployment pipelines, and both should be treated with the same rigour as application development.

The repository is actively maintained and will grow to include additional detections, Bicep modules, and pipeline improvements over time.
