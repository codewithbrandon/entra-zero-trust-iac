# Entra ID Zero Trust as Code

**Terraform that deploys a baseline of Microsoft Entra ID Conditional Access policies and Privileged Identity Management (PIM) just-in-time role access.**

Safe by default: every policy deploys in **report-only mode**, and every policy excludes a break-glass group, so you can measure impact before anything is enforced.

![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?style=flat-square&logo=terraform&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft_Entra_ID-IAM-0078D4?style=flat-square&logo=microsoft&logoColor=white)
![Zero Trust](https://img.shields.io/badge/Zero_Trust-Least_Privilege-darkred?style=flat-square)

---

## Why

Most breaches start with identity: stolen credentials, legacy protocols that skip MFA, and admins with standing access they rarely need. Configuring these controls by hand in the portal is slow, error-prone, and hard to audit.

Defining them in code means they are:
- **Reviewable:** every change goes through a pull request.
- **Repeatable:** the same baseline deploys to dev, test, and production tenants.
- **Auditable:** git history shows who changed what, and when.
- **Drift-resistant:** `terraform plan` shows when someone changed a policy in the portal.

---

## What it deploys

### Conditional Access

| Policy | What it does | Why |
|---|---|---|
| **CA001** Block legacy authentication | Blocks Exchange ActiveSync and other legacy protocols | They can't do MFA, so they're a top password-spray target |
| **CA002** Require MFA for admins | MFA (optionally phishing-resistant) for 14 privileged roles | Admin accounts are the highest-value target |
| **CA003** Require MFA for all users | Baseline MFA everywhere | MFA blocks the vast majority of account compromise attacks |
| **CA004** Require MFA for Azure management | MFA for the portal, CLI, PowerShell, and ARM | Anyone who can change infrastructure must prove who they are |
| **CA005** Block unapproved countries | Blocks sign-ins from outside an allowlist | Shrinks the attack surface to where you actually operate |
| **CA006** High user risk → password change | MFA + secure password reset when ID Protection flags likely compromise | Automated response to leaked credentials *(P2)* |
| **CA007** Risky sign-in → MFA | MFA for medium or high sign-in risk | Challenges anomalous sign-ins in real time *(P2)* |

**Built-in guardrails**
- **Report-only by default** (`enabledForReportingButNotEnforced`)
- **Break-glass exclusion** on every policy, with `prevent_destroy` on the group
- **Input validation:** Terraform refuses to run without at least one emergency access account

### Privileged Identity Management

Two patterns are included:

**1. Direct eligible role assignments** (`pim_roles.tf`)
Users are made *eligible* for a directory role instead of holding it permanently, and activate it just-in-time in PIM.

**2. PIM for Groups** (`pim_groups.tf`): activation rules defined in code

```
user ──(eligible membership, activated in PIM)──▶ role-assignable group ──(role assignment)──▶ directory role
```

The group always holds the role, but nobody is in the group until they activate. Every activation:
- requires **MFA** and a **justification**
- is **time-boxed** (4 hours by default)
- can require **approval** from a designated group
- notifies admins

Eligibility expires after 365 days at most, so access gets re-reviewed rather than accumulating.

---

## Prerequisites

- A **test or development tenant.** Don't run this against production until you've reviewed it.
- **Microsoft Entra ID P2** licensing for PIM and the risk-based policies. Set `enable_risk_based_policies = false` if you only have P1.
- **Two emergency access (break-glass) accounts**, created manually: cloud-only, long random passwords, ideally FIDO2 keys. They're created by hand so their credentials never pass through Terraform or its state.
- Terraform ≥ 1.6

### Permissions

| Running as | Needs |
|---|---|
| **A user** (`az login`) | Conditional Access Administrator + Privileged Role Administrator + Groups Administrator. Global Administrator also works in a test tenant. |
| **A service principal** | Microsoft Graph application permissions (least privilege): `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All`, `RoleManagement.ReadWrite.Directory`, `Group.Create`, `User.Read.All`, `PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup`, `RoleManagementPolicy.ReadWrite.AzureADGroup` |

For CI/CD, use **workload identity federation (OIDC)** rather than a client secret.

---

## Usage

```bash
git clone https://github.com/codewithbrandon/entra-zero-trust-iac.git
cd entra-zero-trust-iac

cp terraform.tfvars.example terraform.tfvars   # fill in your test-tenant values
az login --tenant <tenant-id> --allow-no-subscriptions

terraform init
terraform plan
terraform apply
```

### Rolling out safely

1. **Deploy in report-only mode** (the default).
2. **Watch the impact** for 1–2 weeks in **Entra admin center → Sign-in logs → Report-only** and in the **Conditional Access insights and reporting** workbook.
3. **Fix the gaps:** users without MFA registered, service accounts on legacy auth, travelers.
4. **Enforce:** set `ca_policy_state = "enabled"` and run `terraform apply`.
5. **Monitor break-glass sign-ins** with an alert rule (e.g. in Microsoft Sentinel). They should almost never happen.

---

## Repository layout

```
├── versions.tf               # Terraform + provider versions, optional remote backend
├── providers.tf              # azuread provider (auth comes from the environment)
├── variables.tf              # Inputs, with validation
├── locals.tf                 # Role template IDs, well-known app IDs, user lookups
├── groups.tf                 # Break-glass exclusion group
├── named_locations.tf        # Country allowlist
├── conditional_access.tf     # CA001–CA007
├── pim_roles.tf              # Direct PIM eligible role assignments
├── pim_groups.tf             # PIM for Groups with codified activation rules
├── outputs.tf
├── terraform.tfvars.example  # Sample inputs (real tfvars are gitignored)
└── .github/workflows/        # fmt, validate, TFLint, Checkov: no tenant access, never applies
```

---

## Design decisions

- **Report-only first.** A CA policy that's wrong can lock out an entire organization. Measuring before enforcing is non-negotiable.
- **Break-glass accounts live outside Terraform.** Their credentials shouldn't exist in state files, pipelines, or anyone's laptop.
- **Groups are excluded, not users.** Excluding one group keeps every policy consistent and makes exclusions auditable in one place.
- **Just-in-time over standing access.** Nobody holds Security Administrator 24/7. They activate it when they need it, with MFA and a reason, for a few hours.
- **CI never touches a tenant.** Pipelines run static checks only. Applying is a deliberate, reviewed step.

---

## Known limitations

- **Activation settings for directory roles** (pattern 1: maximum duration, MFA on activation, approval) aren't exposed by the `azuread` provider. Configure them in **Identity Governance → Privileged Identity Management → Microsoft Entra roles → Settings**, or use the PIM for Groups pattern, where they're defined in code.
- Direct role eligibility created by `azuread_directory_role_eligibility_schedule_request` is **permanent** (no expiry). PIM for Groups eligibility does expire.
- Conditional Access APIs are rate-limited (about 1 request per second). Terraform retries automatically, but large changes can take a few minutes.

---

## Mapped to SC-300 skills

| SC-300 area | Where it's demonstrated |
|---|---|
| Plan and implement Conditional Access | `conditional_access.tf`, `named_locations.tf` |
| Implement authentication methods / authentication strengths | CA002 phishing-resistant option |
| Manage risk with Entra ID Protection | CA006, CA007 |
| Plan and implement Privileged Identity Management | `pim_roles.tf`, `pim_groups.tf` |
| Emergency access accounts | `groups.tf`, input validation |

---

## Disclaimer

This is a learning and reference baseline, not a drop-in production configuration. Review every policy against your organization's requirements before enforcing it.

**Built by [Brandon Harris](https://www.linkedin.com/in/brand0n-harris)** · [GitHub](https://github.com/codewithbrandon)
