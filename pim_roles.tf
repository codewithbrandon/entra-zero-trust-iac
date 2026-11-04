# PIM: eligible directory role assignments.
#
# Instead of standing (permanent) admin access, users are made ELIGIBLE for a
# role and activate it just-in-time in PIM when they need it.
#
# Note: this resource creates permanent *eligibility*. Activation settings for
# directory roles (max duration, MFA on activation, approval) aren't exposed by
# the azuread provider, so configure them in Entra admin center:
# Identity Governance > PIM > Microsoft Entra roles > Settings.
# For activation rules in code, use the PIM for Groups pattern in pim_groups.tf.

resource "azuread_directory_role_eligibility_schedule_request" "eligible" {
  for_each = var.pim_eligible_role_assignments

  role_definition_id = local.directory_roles[each.value.role]
  principal_id       = data.azuread_user.referenced[each.value.user_principal_name].object_id
  directory_scope_id = "/"
  justification      = each.value.justification
}
