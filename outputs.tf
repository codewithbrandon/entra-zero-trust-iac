output "conditional_access_policies" {
  description = "Deployed Conditional Access policies and the state they were deployed in."
  value = {
    state = var.ca_policy_state
    policies = compact(concat(
      [
        azuread_conditional_access_policy.ca001_block_legacy_auth.display_name,
        azuread_conditional_access_policy.ca002_mfa_admins.display_name,
        azuread_conditional_access_policy.ca003_mfa_all_users.display_name,
        azuread_conditional_access_policy.ca004_mfa_azure_management.display_name,
        azuread_conditional_access_policy.ca005_block_unapproved_countries.display_name,
      ],
      azuread_conditional_access_policy.ca006_high_user_risk[*].display_name,
      azuread_conditional_access_policy.ca007_risky_sign_in[*].display_name,
    ))
  }
}

output "emergency_access_group_id" {
  description = "Object ID of the break-glass exclusion group."
  value       = azuread_group.ca_exclude_emergency_access.object_id
}

output "pim_eligible_role_assignments" {
  description = "Direct PIM eligibilities: label => role."
  value       = { for k, v in var.pim_eligible_role_assignments : k => v.role }
}

output "privileged_access_groups" {
  description = "PIM for Groups: group name => role it grants on activation."
  value       = { for k, v in var.privileged_access_groups : azuread_group.privileged_access[k].display_name => v.role }
}
