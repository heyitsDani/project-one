terraform {
  required_version = ">=  1.9.1"
  required_providers {
    azurerm = "~>3.108.0"
    azuread = "~>2.46.0"
  }

}
provider "azurerm" {
  features {}
  subscription_id    = local.env_content["SUBSCRIPTION_ID"]
  tenant_id          = local.env_content["TENANT_ID"]
  client_id          = local.env_content["AZ_CLIENT_ID"]
  client_secret      = local.env_content["AZ_CLIENT_SECRET"]
  # skip_provider_registration = true
}


provider "azuread" {
  client_id          = local.env_content["AZ_CLIENT_ID"]
  client_secret      = local.env_content["AZ_CLIENT_SECRET"]
  tenant_id     = local.env_content["TENANT_ID"]
}