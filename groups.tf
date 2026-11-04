# Emergency access (break-glass) exclusion group.
# Every Conditional Access policy excludes this group. Monitor sign-ins by these
# accounts with an alert rule in Sentinel, since they should almost never be used.
resource "azuread_group" "ca_exclude_emergency_access" {
  display_name     = "${var.name_prefix}-CA-Exclude-EmergencyAccess"
  description      = "Break-glass accounts excluded from all Conditional Access policies. Managed by Terraform."
  security_enabled = true
  members          = var.emergency_access_account_object_ids

  lifecycle {
    prevent_destroy = true
  }
}
