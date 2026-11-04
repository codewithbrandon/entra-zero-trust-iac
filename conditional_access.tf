# Baseline Zero Trust Conditional Access policies.
# All of them:
#   - deploy in report-only mode by default (var.ca_policy_state)
#   - exclude the emergency access group
#   - follow a CAxxx naming convention so they sort and audit cleanly

# CA001: Legacy authentication protocols can't do MFA, so they're a top
# password-spray target. Block them outright.
resource "azuread_conditional_access_policy" "ca001_block_legacy_auth" {
  display_name = "${var.name_prefix}-CA001-Block-LegacyAuthentication"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# CA002: Privileged roles get the strongest control. Optionally require
# phishing-resistant MFA instead of any MFA method.
resource "azuread_conditional_access_policy" "ca002_mfa_admins" {
  display_name = "${var.name_prefix}-CA002-Require-MFA-Admins"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_roles  = local.privileged_role_ids
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator                          = "OR"
    built_in_controls                 = var.require_phishing_resistant_mfa_for_admins ? null : ["mfa"]
    authentication_strength_policy_id = var.require_phishing_resistant_mfa_for_admins ? local.phishing_resistant_strength_id : null
  }
}

# CA003: Baseline MFA for every user.
resource "azuread_conditional_access_policy" "ca003_mfa_all_users" {
  display_name = "${var.name_prefix}-CA003-Require-MFA-AllUsers"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# CA004: Azure management (portal, CLI, PowerShell, ARM) can change
# infrastructure, so it always requires MFA, even for non-admin users.
resource "azuread_conditional_access_policy" "ca004_mfa_azure_management" {
  display_name = "${var.name_prefix}-CA004-Require-MFA-AzureManagement"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = [local.azure_management_app_id]
    }

    users {
      included_users  = ["All"]
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# CA005: Block sign-ins from outside the countries the organization operates in.
resource "azuread_conditional_access_policy" "ca005_block_unapproved_countries" {
  display_name = "${var.name_prefix}-CA005-Block-UnapprovedCountries"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    locations {
      included_locations = ["All"]
      excluded_locations = [azuread_named_location.allowed_countries.id]
    }

    users {
      included_users  = ["All"]
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# CA006: High user risk (likely compromised credentials). Require MFA
# and a secure password change. Requires Entra ID P2.
resource "azuread_conditional_access_policy" "ca006_high_user_risk" {
  count = var.enable_risk_based_policies ? 1 : 0

  display_name = "${var.name_prefix}-CA006-HighUserRisk-Require-PasswordChange"
  state        = var.ca_policy_state

  conditions {
    client_app_types = ["all"]
    user_risk_levels = ["high"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator          = "AND"
    built_in_controls = ["mfa", "passwordChange"]
  }
}

# CA007: Medium or high sign-in risk (anomalous sign-in, e.g. impossible
# travel or an anonymous IP). Require MFA. Requires Entra ID P2.
resource "azuread_conditional_access_policy" "ca007_risky_sign_in" {
  count = var.enable_risk_based_policies ? 1 : 0

  display_name = "${var.name_prefix}-CA007-RiskySignIn-Require-MFA"
  state        = var.ca_policy_state

  conditions {
    client_app_types    = ["all"]
    sign_in_risk_levels = ["medium", "high"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = local.ca_excluded_groups
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
