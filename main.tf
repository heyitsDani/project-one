#####################################
## locals - central location for aliases. 
## Aliases serve as shortcuts to infra configurations inside ~/environments/*.json
#####################################
locals {
    env         = "prod"
    env_dir     = "./environments/"
    master_key  = "${local.env_dir}${local.env}.tfvars.json"

    tenant_id   = data.azurerm_client_config.current.tenant_id
    client_id   = data.azurerm_client_config.current.client_id
    object_id   = data.azurerm_client_config.current.object_id
    id          = data.azurerm_client_config.current.id
    env_content = jsondecode(file(".env"))
    tags        = merge(var.application_tags, var.environment_tags)

    org = jsondecode(file("${local.master_key}"))["organizational_data"]

    # snets = jsondecode(file("${local.master_key}"))["subnets"]
    rgs   = jsondecode(file("${local.master_key}"))["organizational_data"]["resource_groups"]["dev"]

    ids = jsondecode(file("${local.master_key}"))["identities"]["instances"]

    vnets = jsondecode(file("${local.master_key}"))["vnet"]["instances"]
    vnets_data = jsondecode(file("${local.master_key}"))["vnet"]["configuration"]

    snets = jsondecode(file("${local.master_key}"))["subnet"]["instances"]

    storage = jsondecode(file("${local.master_key}"))["storage_account"]["instances"]
    storage_data = jsondecode(file("${local.master_key}"))["storage_account"]["configuration"]

    acr =  jsondecode(file("${local.master_key}"))["container_registry"]["instances"]
    acr_data =  jsondecode(file("${local.master_key}"))["container_registry"]["configuration"]

    asp_base = jsondecode(file("${local.master_key}"))["app_service"]["plans"]["base"]
    asp_ai = jsondecode(file("${local.master_key}"))["app_service"]["plans"]["ai"]

    asp_base_data = jsondecode(file("${local.master_key}"))["app_service"]["plans"]["configurations"]["base"]
    asp_ai_data = jsondecode(file("${local.master_key}"))["app_service"]["plans"]["configurations"]["ai"]

    app_base = jsondecode(file("${local.master_key}"))["app_service"]["applications"]["base"]
    app_ai = jsondecode(file("${local.master_key}"))["app_service"]["applications"]["ai"]

    app_base_data = jsondecode(file("${local.master_key}"))["app_service"]["applications"]["configurations"]["base"]
    app_ai_data = jsondecode(file("${local.master_key}"))["app_service"]["applications"]["configurations"]["ai"]

    psql = jsondecode(file("${local.master_key}"))["postgres"]["instances"]
    psql_data = jsondecode(file("${local.master_key}"))["postgres"]["configuration"]

    oai = jsondecode(file("${local.master_key}"))["cognitive_services"]["instances"]["openai"]
    oai_data = jsondecode(file("${local.master_key}"))["cognitive_services"]["configuration"]["openai"]
}

#####################################
## Data Objects
#####################################
data "azurerm_client_config" "current" {} // Client session of TF 
data "azurerm_subscription" "primary" {} // Subscription set in versions.tf


data "azurerm_resource_group" "network" {
    name = local.rgs.rg1.name
}

data "azurerm_resource_group" "infrastructure" {
    name = local.rgs.rg2.name
}


data "azurerm_service_plan" "asp_ai" {
  name                = local.asp_ai.asp1.name
  resource_group_name = local.rgs.rg2.name
}

data "azurerm_service_plan" "asp_base_ux" {
  name                = local.asp_base.asp1.name
  resource_group_name = local.rgs.rg2.name
}

data "azurerm_service_plan" "asp_base_be" {
  name                = local.asp_base.asp2.name
  resource_group_name = local.rgs.rg2.name
}

# data "azurerm_container_registry" "acr" {
#     name = local.acr.acr1.name
#     resource_group_name = local.rgs.rg2.name
# }

data "azurerm_subnet" "subnet_backend" {
    name = local.snets.s2.name
    resource_group_name = local.rgs.rg1.name
    virtual_network_name = local.vnets.v1.name

}

data "azurerm_subnet" "subnet_ux" {
    name = local.snets.s1.name
    resource_group_name = local.rgs.rg1.name
    virtual_network_name = local.vnets.v1.name

}


#####################################
## Resource groups
#####################################
resource "azurerm_resource_group" "resource_groups" { 
  for_each = { for k, v in local.rgs: k => v }
  name = each.value.name
  location = each.value.location
  tags = local.tags

}

#####################################
## Identities
#####################################
resource "azurerm_user_assigned_identity" "identity_devops" {
    name                = local.ids.id2.name
    resource_group_name = local.rgs.rg2.name
    location            = local.org.locations.1
}


# #####################################
# ## Roles
# #####################################
resource "azurerm_role_assignment" "assign_owner_acr" {
  scope                = "/subscriptions/9f83745b-0fcb-442e-a631-f58996e73e66"
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.identity_devops.principal_id
}
# #####################################
# ## Virtual Networks
# #####################################
resource "azurerm_virtual_network" "vnets_diesl_org" {
    for_each = { for k, v in local.vnets: k => v }
    name                = each.value.name 
    location            = each.value.location
    resource_group_name = data.azurerm_resource_group.network.name
    address_space       = local.vnets_data.address_space
    tags = local.tags
}

# #####################################
# ## Sub Nets
# #####################################
resource "azurerm_subnet" "subnets" { 
  for_each = { for k, v in local.snets: k => v }
  name = each.value.name
  address_prefixes = [each.value.cidr]
  virtual_network_name = local.vnets.v1.name
  resource_group_name = local.rgs.rg1.name
  service_endpoints = each.value.service_endpoints

  lifecycle {
    ignore_changes = [ delegation ]
  }
}

# #####################################
# ## Storage Account
# #####################################
resource "azurerm_storage_account" "storage_accounts" {
    for_each = { for k, v in local.storage: k => v }
    name                     = each.value.name
    resource_group_name      = local.rgs.rg2.name
    location                 = local.org.locations.1
    account_tier             = local.storage_data.account_tier
    account_replication_type = local.storage_data.account_replication_type
    account_kind             = local.storage_data.account_kind

    tags = local.tags
}

# #####################################
# ## Container Registry
# #####################################
# resource "azurerm_container_registry" "acr" {
#     for_each = { for k, v in local.acr: k => v }
#     name                = each.value.name
#     resource_group_name = local.rgs.rg2.name
#     location            = local.org.locations.1
#     sku                 = local.acr_data.sku
#     # admin_enabled       = local.acr_data.admin_enabled

#     identity {
#         type = "UserAssigned"
#         identity_ids = [
#             azurerm_user_assigned_identity.identity_devops.id
#         ]
#     }
    
#     depends_on = [ azurerm_user_assigned_identity.identity_devops ]

#     lifecycle {
#       ignore_changes = [ identity ]
#     }
# }

#####################################
## Postgres 
#####################################
# resource "azurerm_postgresql_flexible_server" "flexible_server" {
#     for_each = { for k, v in local.psql: k => v }

#     name                   = each.value.name
#     resource_group_name    = local.rgs.rg2.name
#     location               = local.org.locations.1
#     version                = local.psql_data.version
#     administrator_login    = local.env_content["POSTGRESQL_USERNAME"]
#     administrator_password = local.env_content["POSTGRESQL_PASSWORD_DEV"]
#     zone                   = local.psql_data.zone
#     # public_network_access_enabled = false
#     storage_mb   = local.psql_data.storage_mb
#     sku_name   = local.psql_data.sku_name
#     tags = local.tags
#     # depends_on = [azurerm_private_dns_zone_virtual_network_link.network_link_psql]

# }

# #####################################
# ## Postgres 
# #####################################
# # resource "azurerm_postgresql_flexible_server" "flexible_server" {
# #     for_each = { for k, v in local.psql: k => v }

# #     name                   = each.value.name
# #     resource_group_name    = local.rgs.rg2.name
# #     location               = local.org.locations.1
# #     version                = local.psql_data.version
# #     administrator_login    = local.env_content["POSTGRESQL_USERNAME"]
# #     administrator_password = local.env_content["POSTGRESQL_PASSWORD_DEV"]
# #     zone                   = local.psql_data.zone
# #     # public_network_access_enabled = false
# #     storage_mb   = local.psql_data.storage_mb
# #     sku_name   = local.psql_data.sku_name
# #     tags = local.tags
# #     # depends_on = [azurerm_private_dns_zone_virtual_network_link.network_link_psql]

# # }

# #####################################
# ## Key Vault
# #####################################


# #####################################
# ## App Service Plan
# #####################################
resource "azurerm_service_plan" "plan_base" {
    for_each = { for k, v in local.asp_base: k => v }
    name                       = each.value.name
    resource_group_name        = local.rgs.rg2.name
    location                   = local.org.locations.1
    os_type                    = local.asp_base_data.os_type
    sku_name                   = local.asp_base_data.sku_name

    timeouts {
        create = "120m"  # Adjust the timeout value as needed
    }

    tags = local.tags
}

resource "azurerm_service_plan" "plan_ai" {
    for_each = { for k, v in local.asp_ai: k => v }
    name                       = each.value.name
    resource_group_name        = local.rgs.rg2.name
    location                   = local.org.locations.1
    os_type                    = local.asp_ai_data.os_type
    sku_name                   = local.asp_ai_data.sku_name
    timeouts {
        create = "120m"  # Adjust the timeout value as needed
    }

    tags = local.tags
}

# #####################################
# ## App Services
# #####################################


resource "azurerm_linux_web_app" "app_ai" {

    name = local.app_ai.app1.name
    location            = local.org.locations.1 
    resource_group_name = local.rgs.rg2.name
    service_plan_id = data.azurerm_service_plan.asp_ai.id
    tags = local.tags

    site_config {
        always_on = true
        health_check_path = "/health"
        container_registry_use_managed_identity = true 
        container_registry_managed_identity_client_id = azurerm_user_assigned_identity.identity_devops.client_id
        vnet_route_all_enabled                        = true

        cors { 
            allowed_origins = ["*"]
        }

        application_stack {
          docker_image_name = local.env_content["DIESL_AI_IMAGE"]
          docker_registry_url = local.env_content["ACR_URL"]
          docker_registry_username = local.env_content["ACR_USERNAME"]
          docker_registry_password = local.env_content["ACR_PASSWORD"]
        }
    }

    logs{
        http_logs {
            file_system {
                retention_in_mb = 35
                retention_in_days = 30 
            }
        }
    }

    identity {
        type = "UserAssigned"
        identity_ids = [ azurerm_user_assigned_identity.identity_devops.id]
    }

    app_settings = {
        # "WEBSITE_HEALTHCHECK_MAXPINGFAILURES" = "10"
        "ACCESS_TYPE_O365"                    = local.env_content["ACCESS_TYPE_O365"]
        "ACCESS_URL_O365"                     = local.env_content["ACCESS_URL_O365"]
        "AUTH_TOKEN"                          = local.env_content["AUTH_TOKEN"]
        "DOCKER_REGISTRY_SERVER_URL"          = local.env_content["ACR_URL"]
        "DOCKER_REGISTRY_SERVER_USERNAME"     = local.env_content["ACR_USERNAME"]
        "DOCKER_REGISTRY_SERVER_PASSWORD"     = local.env_content["ACR_PASSWORD"]
        "ENV_PROFILE"                         = local.env_content["ENV_PROFILE"]
        "LANGCHAIN_API_KEY"                   = local.env_content["LANGCHAIN_API_KEY"]
        "LANGCHAIN_TRACING_V2"                = local.env_content["LANGCHAIN_TRACING_V2"]
        "LEAVE_DRIVER_OPEN"                   = local.env_content["LEAVE_DRIVER_OPEN"]
        "OPENAI_API_BASE"                      = local.env_content["OPENAI_API_BASE"]
        "OPENAI_API_KEY"                  = local.env_content["OPENAI_API_KEY"]
        "OPENAI_API_VERSION"                  = local.env_content["OPENAI_API_VERSION"]
        "STORAGE_CONNECTION_STRING"           = local.env_content["CONNECTION_STRING"]
    }

}

resource "azurerm_linux_web_app" "app_base_be" {
    name                = local.app_base.app2.name
    location            = local.org.locations.1
    resource_group_name = local.rgs.rg2.name
    service_plan_id = data.azurerm_service_plan.asp_base_be.id
    virtual_network_subnet_id = data.azurerm_subnet.subnet_backend.id
    public_network_access_enabled = true
    tags = local.tags 

    site_config {
        ip_restriction_default_action                 = "Allow"
        vnet_route_all_enabled                        = true
        always_on = true
        health_check_path = "/health"
        container_registry_use_managed_identity = true 
        container_registry_managed_identity_client_id = azurerm_user_assigned_identity.identity_devops.client_id

        cors { 
            allowed_origins = ["*"]
        }
        
        application_stack {
          docker_image_name = local.env_content["DIESL_BACKEND_IMAGE"]
          docker_registry_url = local.env_content["ACR_URL"]
          docker_registry_username = local.env_content["ACR_USERNAME"]
          docker_registry_password = local.env_content["ACR_PASSWORD"]
        }

        ip_restriction {
            action                    = "Allow"
            headers                   = [] 
            name                      = "Allow - Frontend" 
            priority                  = 300
            virtual_network_subnet_id = "/subscriptions/9f83745b-0fcb-442e-a631-f58996e73e66/resourceGroups/DIESL-EUS-NTWRK-RG-01/providers/Microsoft.Network/virtualNetworks/DIESL-EUS-INFRA-VNET-01/subnets/DIESL-EUS-UX-SNET-01"
        }

        ip_restriction {
            action                    = "Allow" 
            headers                   = [] 
            name                      = "Allow - Backend" 
            priority                  = 100 
            virtual_network_subnet_id = "/subscriptions/9f83745b-0fcb-442e-a631-f58996e73e66/resourceGroups/DIESL-EUS-NTWRK-RG-01/providers/Microsoft.Network/virtualNetworks/DIESL-EUS-INFRA-VNET-01/subnets/DIESL-EUS-BE-SNET-01" 
        }

        ip_restriction {
            action                    = "Allow" 
            headers                   = [] 
            name                      = "Allow - PE" 
            priority                  = 200 
            virtual_network_subnet_id = "/subscriptions/9f83745b-0fcb-442e-a631-f58996e73e66/resourceGroups/DIESL-EUS-NTWRK-RG-01/providers/Microsoft.Network/virtualNetworks/DIESL-EUS-INFRA-VNET-01/subnets/DIESL-EUS-PE-SNET-01" 
        }

        # ip_restriction {
        #     action                    = "Deny" 
        #     headers                   = [] 
        #     name                      = "Deny - Public" 
        #     priority                  = 400 
        #     ip_address                = "0.0.0.0/0"
        # }


    }

    logs{
        http_logs {
            file_system {
                retention_in_mb = 35
                retention_in_days = 30
            }
        }
    }

    identity {
        type = "UserAssigned"
        identity_ids = [ azurerm_user_assigned_identity.identity_devops.id]
    }

    app_settings = {
        "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
        "DOCKER_REGISTRY_SERVER_URL"          = local.env_content["ACR_URL"]
        "DOCKER_REGISTRY_SERVER_USERNAME"     = local.env_content["ACR_USERNAME"]
        "DOCKER_REGISTRY_SERVER_PASSWORD"     = local.env_content["ACR_PASSWORD"]
        "SPRING_DATASOURCE_URL"               = local.env_content["POSTGRESQL_CONNECTION_URL_DEV"]
        "SPRING_DATASOURCE_USERNAME"          = local.env_content["POSTGRESQL_USERNAME"]
        "SPRING_DATASOURCE_PASSWORD"          = local.env_content["POSTGRESQL_PASSWORD_DEV"]
        # "APPINSIGHTS_INSTRUMENTATIONKEY"      = "1eee47cc-387e-43ab-80dc-85bfc908dc4e" 
        # "APPINSIGHTS_PROFILERFEATURE_VERSION"             = local.env_content["1.0.0"]
        # "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = local.env_content["1.0.0"]
        # "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"       = local.env_content[null]
        # "APPLICATIONINSIGHTS_CONNECTION_STRING"           = local.env_content["InstrumentationKey=1eee47cc-387e-43ab-80dc-85bfc908dc4e;IngestionEndpoint=https://eastus2-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus2.livediagnostics.monitor.azure.com/;ApplicationId=c7dcbd8b-1aaa-421e-bde1-b90ad088736d"]
        "AZ_CLIENT_ID"                                    = local.env_content["AZ_CLIENT_ID"]
        "AZ_CLIENT_SECRET"                              = local.env_content["AZ_CLIENT_SECRET"]
        "AZ_KV_URL"                                     = local.env_content["AZ_KV_URL"]
        "AZ_TENANT_ID"                                  = local.env_content["AZ_TENANT_ID"]
        # "ApplicationInsightsAgent_EXTENSION_VERSION"    = local.env_content["~3"]
        "CONNECTION_STRING"                             = local.env_content["CONNECTION_STRING"]
        "DIESL_AI_BEARER_TOKEN"                         = local.env_content["DIESL_AI_BEARER_TOKEN"]
        "DIESL_AI_HOST"                                 = local.env_content["DIESL_AI_HOST"]
        "DIESL_BACKEND_HOST"                            = local.env_content["DIESL_BACKEND_HOST"]
        "DIESL_TF_AGENTS"                               = local.env_content["DIESL_TF_AGENTS"]
        # "DiagnosticServices_EXTENSION_VERSION"          = local.env_content["~3"]
        # "InstrumentationEngine_EXTENSION_VERSION"       = local.env_content["disabled"]
        "SAS_TOKEN"                                     = local.env_content["SAS_TOKEN"]
        "SMTP_PASSWORD"                                 = local.env_content["SMTP_PASSWORD"]
        # "SnapshotDebugger_EXTENSION_VERSION"            = local.env_content["disabled"]
        # "WEBSITE_HEALTHCHECK_MAXPINGFAILURES"           = local.env_content["10"]
        # "XDT_MicrosoftApplicationInsights_BaseExtensions"= local.env_content["disabled"]
        # "XDT_MicrosoftApplicationInsights_Mode"         = local.env_content["recommended"]
        # "XDT_MicrosoftApplicationInsights_PreemptSdk"   = local.env_content["disabled"]

    }

    lifecycle {
        ignore_changes = [app_settings, sticky_settings, tags]
    }

}

resource "azurerm_linux_web_app" "app_base_ux" {
  name                = local.app_base.app1.name
  location            = local.org.locations.1
  resource_group_name = local.rgs.rg2.name
  service_plan_id = data.azurerm_service_plan.asp_base_ux.id
  https_only = true
  virtual_network_subnet_id = data.azurerm_subnet.subnet_ux.id
  tags = local.tags


  site_config {
    vnet_route_all_enabled = true
    always_on = true
    health_check_path = "/"
    container_registry_use_managed_identity = true 
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.identity_devops.client_id

    application_stack {
        docker_image_name = local.env_content["DIESL_FRONTEND_IMAGE"]
        docker_registry_url = local.env_content["ACR_URL"]
        docker_registry_username = local.env_content["ACR_USERNAME"]
        docker_registry_password = local.env_content["ACR_PASSWORD"]

    }
    cors { 
      allowed_origins = ["*"]
    }
  }

  logs{
    http_logs {
      file_system {
        retention_in_mb = 35
        retention_in_days = 30
      }
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.identity_devops.id ]
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "NEXT_PUBLIC_RECAPTCHA_SITE_KEY" = local.env_content["NEXT_PUBLIC_RECAPTCHA_SITE_KEY"]
    "RECAPTCHA_SECRET_KEY" = local.env_content["RECAPTCHA_SECRET_KEY"]
    "NEXT_PUBLIC_BACKEND_DOMAIN_NAME" = local.env_content["NEXT_PUBLIC_BACKEND_DOMAIN_NAME"]
    # "NEXT_PUBLIC_BACKEND_API_VERSION" =local.env_content["NEXT_PUBLIC_BACKEND_API_VERSION"]
  }

  lifecycle {
    ignore_changes = [ site_config, app_settings, sticky_settings]
  }

}

resource "azurerm_cognitive_account" "openai" {
    for_each = { for k, v in local.oai: k => v }
    name = each.value.name
    location            = local.org.locations.1
    resource_group_name = local.rgs.rg2.name
    kind                = local.oai_data.kind

    sku_name = "S0"
    tags = local.tags

    lifecycle {
      ignore_changes = [ custom_subdomain_name ]
    }
}
