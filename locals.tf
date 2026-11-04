locals {
  # Built-in Entra ID directory role template IDs.
  # These are the same in every tenant.
  directory_roles = {
    GlobalAdministrator                   = "62e90394-69f5-4237-9190-012177145e10"
    PrivilegedRoleAdministrator           = "e8611ab8-c189-46e8-94e1-60213ab1f814"
    PrivilegedAuthenticationAdministrator = "7be44c8a-adaf-4e2a-84d6-ab2649e08a13"
    SecurityAdministrator                 = "194ae4cb-b126-40b2-bd5b-6091b380977d"
    ConditionalAccessAdministrator        = "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9"
    UserAdministrator                     = "fe930be7-5e62-47db-91af-98c3a49a38b1"
    AuthenticationAdministrator           = "c4e39bd9-1100-46d3-8c65-fb160da0071f"
    HelpdeskAdministrator                 = "729827e3-9c14-49f7-bb1b-9608f156bbb8"
    PasswordAdministrator                 = "966707d0-3269-4727-9be2-8c3a10f19b9d"
    ApplicationAdministrator              = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
    CloudApplicationAdministrator         = "158c047a-c907-4556-b7ef-446551a6b5f7"
    ExchangeAdministrator                 = "29232cdf-9323-42fd-ade2-1d097af3e4de"
    SharePointAdministrator               = "f28a1f50-f6e7-4571-818b-6a12f2af6b6c"
    BillingAdministrator                  = "b0f54661-2d74-4c50-afa3-1ec803f12efe"
    SecurityReader                        = "5d6b6bb7-de71-4623-b4af-96380a352509"
    GlobalReader                          = "f2ef992c-3afb-46b9-b7cf-a126ee74c451"
  }

  # Highly privileged roles that CA002 targets, based on Microsoft's
  # "Require MFA for administrators" policy template.
  privileged_role_ids = [
    local.directory_roles.GlobalAdministrator,
    local.directory_roles.PrivilegedRoleAdministrator,
    local.directory_roles.PrivilegedAuthenticationAdministrator,
    local.directory_roles.SecurityAdministrator,
    local.directory_roles.ConditionalAccessAdministrator,
    local.directory_roles.UserAdministrator,
    local.directory_roles.AuthenticationAdministrator,
    local.directory_roles.HelpdeskAdministrator,
    local.directory_roles.PasswordAdministrator,
    local.directory_roles.ApplicationAdministrator,
    local.directory_roles.CloudApplicationAdministrator,
    local.directory_roles.ExchangeAdministrator,
    local.directory_roles.SharePointAdministrator,
    local.directory_roles.BillingAdministrator,
  ]

  # Well-known app ID for "Windows Azure Service Management API"
  # (Azure portal, Azure CLI, Azure PowerShell, ARM).
  azure_management_app_id = "797f4846-ba00-4fd7-ba43-dac1f8f63013"

  # Built-in "Phishing-resistant MFA" authentication strength.
  phishing_resistant_strength_id = "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000004"

  # Every policy excludes the emergency access (break-glass) group,
  # so a misconfigured policy can never lock the tenant out.
  ca_excluded_groups = [azuread_group.ca_exclude_emergency_access.object_id]

  # Flatten PIM-for-Groups membership into one entry per (group, user) pair.
  pim_group_memberships = merge([
    for group_key, group in var.privileged_access_groups : {
      for upn in group.eligible_member_upns :
      "${group_key}|${upn}" => {
        group_key = group_key
        upn       = upn
      }
    }
  ]...)

  # Every UPN referenced anywhere, looked up once.
  all_referenced_upns = toset(concat(
    [for a in values(var.pim_eligible_role_assignments) : a.user_principal_name],
    flatten([for g in values(var.privileged_access_groups) : g.eligible_member_upns]),
  ))
}

data "azuread_user" "referenced" {
  for_each            = local.all_referenced_upns
  user_principal_name = each.value
}
