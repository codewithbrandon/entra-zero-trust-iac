terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # Local state by default. For team use, store state remotely and lock it down.
  # State contains object IDs and policy configuration, so treat it as sensitive.
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstateXXXX"
  #   container_name       = "tfstate"
  #   key                  = "entra-zero-trust.tfstate"
  #   use_azuread_auth     = true
  # }
}
