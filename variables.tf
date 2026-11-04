variable "name_prefix" {
  description = "Prefix for every object this repo creates, so they're easy to find and audit in the portal."
  type        = string
  default     = "ZT"
}

# ---------------------------------------------------------------------------
# Conditional Access
# ---------------------------------------------------------------------------

variable "ca_policy_state" {
  description = <<-EOT
    State applied to every Conditional Access policy.
    Defaults to report-only so nothing is enforced until you've reviewed the
    impact in the sign-in logs and the Conditional Access insights workbook.
  EOT
  type        = string
  default     = "enabledForReportingButNotEnforced"

  validation {
    condition     = contains(["enabled", "disabled", "enabledForReportingButNotEnforced"], var.ca_policy_state)
    error_message = "ca_policy_state must be enabled, disabled, or enabledForReportingButNotEnforced."
  }
}

variable "emergency_access_account_object_ids" {
  description = <<-EOT
    Object IDs of your break-glass accounts. They're excluded from every policy.
    Create these accounts manually (cloud-only, long random passwords, FIDO2 keys)
    so their credentials never pass through Terraform or its state.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.emergency_access_account_object_ids) >= 1
    error_message = "Provide at least one emergency access account. Deploying Conditional Access without one risks locking yourself out of the tenant."
  }
}

variable "allowed_countries" {
  description = "ISO 3166 two-letter country codes that sign-ins are allowed from. Everything else is blocked by CA005."
  type        = list(string)
  default     = ["US"]

  validation {
    condition     = alltrue([for c in var.allowed_countries : can(regex("^[A-Z]{2}$", c))])
    error_message = "Use two-letter uppercase ISO 3166 country codes, e.g. \"US\"."
  }
}

variable "require_phishing_resistant_mfa_for_admins" {
  description = "If true, CA002 requires phishing-resistant MFA (FIDO2, Windows Hello, certificate-based) for admin roles instead of any MFA method. Make sure admins have registered a compatible method first."
  type        = bool
  default     = false
}

variable "enable_risk_based_policies" {
  description = "Deploy the user-risk and sign-in-risk policies (CA006, CA007). Requires Entra ID P2 / ID Protection."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# PIM: eligible directory role assignments (direct)
# ---------------------------------------------------------------------------

variable "pim_eligible_role_assignments" {
  description = <<-EOT
    Users who are ELIGIBLE (not permanently active) for a directory role.
    They activate just-in-time through PIM. The map key is a label of your choosing.
    `role` must be a key from local.directory_roles, e.g. "SecurityAdministrator".
  EOT
  type = map(object({
    user_principal_name = string
    role                = string
    justification       = string
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# PIM for Groups: role-assignable groups with codified activation rules
# ---------------------------------------------------------------------------

variable "privileged_access_groups" {
  description = <<-EOT
    Role-assignable groups that hold a directory role. Users get ELIGIBLE
    membership and must activate it through PIM, under the rules set here
    (MFA, justification, a time limit, optional approval).
  EOT
  type = map(object({
    role                     = string
    eligible_member_upns     = list(string)
    max_activation_duration  = optional(string, "PT4H")
    require_approval         = optional(bool, false)
    approver_group_object_id = optional(string)
    eligibility_duration     = optional(string, "P180D")
  }))
  default = {}

  validation {
    condition = alltrue([
      for g in values(var.privileged_access_groups) :
      !g.require_approval || g.approver_group_object_id != null
    ])
    error_message = "When require_approval is true, set approver_group_object_id."
  }

  validation {
    condition = alltrue([
      for g in values(var.privileged_access_groups) :
      contains(["P15D", "P30D", "P90D", "P180D", "P365D"], g.eligibility_duration)
    ])
    error_message = "eligibility_duration must be one of P15D, P30D, P90D, P180D, or P365D."
  }
}
