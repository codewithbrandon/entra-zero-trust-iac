# Authentication is picked up from the environment, so no secrets live in code.
#
# Interactive (local testing):   az login --tenant <tenant-id> --allow-no-subscriptions
# Service principal (CI/CD):     ARM_TENANT_ID, ARM_CLIENT_ID, plus OIDC federation (preferred)
#                                or ARM_CLIENT_SECRET
#
# Required permissions are listed in the README.
provider "azuread" {}
