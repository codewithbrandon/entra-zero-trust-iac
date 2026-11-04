resource "azuread_named_location" "allowed_countries" {
  display_name = "${var.name_prefix}-Allowed-Countries"

  country {
    countries_and_regions                 = var.allowed_countries
    include_unknown_countries_and_regions = false
  }
}
