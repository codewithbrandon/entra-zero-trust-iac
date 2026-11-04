# PIM for Groups: just-in-time access with activation rules defined in code.
#
#   user --(eligible membership, activated via PIM)--> role-assignable group
#   role-assignable group --(active role assignment)--> directory role
#
# The group always holds the role, but nobody is in the group until they
# activate. Activation requires MFA and a justification, is time-boxed, and
# can require approval.

resource "azuread_group" "privileged_access" {
  for_each = var.privileged_access_groups

  display_name       = "${var.name_prefix}-PAG-${each.key}"
  description        = "PIM for Groups: just-in-time ${each.value.role}. Managed by Terraform."
  security_enabled   = true
  assignable_to_role = true
}

resource "azuread_directory_role_assignment" "privileged_access" {
  for_each = var.privileged_access_groups

  role_id             = local.directory_roles[each.value.role]
  principal_object_id = azuread_group.privileged_access[each.key].object_id
}

resource "azuread_group_role_management_policy" "privileged_access_member" {
  for_each = var.privileged_access_groups

  group_id = azuread_group.privileged_access[each.key].id
  role_id  = "member"

  activation_rules {
    maximum_duration                   = each.value.max_activation_duration
    require_justification              = true
    require_multifactor_authentication = true
    require_approval                   = each.value.require_approval

    dynamic "approval_stage" {
      for_each = each.value.require_approval ? [1] : []
      content {
        primary_approver {
          object_id = each.value.approver_group_object_id
          type      = "groupMembers"
        }
      }
    }
  }

  # Eligibility must expire and be re-reviewed. No "forever eligible" admins.
  eligible_assignment_rules {
    expiration_required = true
    expire_after        = "P365D"
  }

  # Discourage standing access: any active assignment expires within 15 days.
  active_assignment_rules {
    expiration_required = true
    expire_after        = "P15D"
  }

  notification_rules {
    eligible_activations {
      admin_notifications {
        notification_level = "All"
        default_recipients = true
      }
    }
  }
}

resource "azuread_privileged_access_group_eligibility_schedule" "privileged_access" {
  for_each = local.pim_group_memberships

  group_id        = azuread_group.privileged_access[each.value.group_key].id
  principal_id    = data.azuread_user.referenced[each.value.upn].object_id
  assignment_type = "member"
  duration        = var.privileged_access_groups[each.value.group_key].eligibility_duration
  justification   = "Eligible ${var.privileged_access_groups[each.value.group_key].role} via PIM for Groups. Managed by Terraform."

  # The policy must exist first, so the eligibility is validated against it.
  depends_on = [azuread_group_role_management_policy.privileged_access_member]
}
