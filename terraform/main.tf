provider "azurerm" {
  features {}
  subscription_id = "5c01b9ab-7e48-4c36-b2c0-4eb091caac88"
}

locals {
  allLocations = concat([var.primary_location], var.additional_locations)
  api_apps_possible_ip_addresses = flatten([
    for geode in module.geode :
    split(",", geode.api_app_possible_ip_addresses)
  ])
  front_door_origin_ids = [
    for origin in azurerm_cdn_frontdoor_origin.frontdoor_origin :
    origin.id
  ]
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "${var.base_name}-rg"
  location = var.primary_location
}

# FRONT DOOR

resource "azurerm_cdn_frontdoor_profile" "frontdoor" {
  name                = "${var.base_name}frontdoor"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = var.front_door_sku
}

resource "azurerm_cdn_frontdoor_endpoint" "frontdoor_endpoint" {
  name                     = "${var.base_name}frontdoorendpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
}

resource "azurerm_cdn_frontdoor_origin_group" "frontdoor_origin_group" {
  name                     = "${var.base_name}frontdoororigingroup"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "frontdoor_origin" {
  count                          = length(module.geode)
  name                           = "${var.base_name}frontdoororigin${count.index}"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group.id
  enabled                        = true
  host_name                      = split("https://", module.geode[count.index].api_management_gateway_url)[1]
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = split("https://", module.geode[count.index].api_management_gateway_url)[1]
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "frontdoor_route" {
  name                          = "${var.base_name}frontdoorroute"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group.id
  cdn_frontdoor_origin_ids      = local.front_door_origin_ids

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "MatchRequest"
  link_to_default_domain = true
  https_redirect_enabled = true
}

resource "azurerm_monitor_diagnostic_setting" "frontdoor_diagnostic_setting" {
  name                       = "frontdoordiagnosticsetting"
  target_resource_id         = azurerm_cdn_frontdoor_profile.frontdoor.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  enabled_log {
    category = "FrontdoorAccessLog"
  }

  metric {
    category = "AllMetrics"
  }
}

# LOG ANALYTICS

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "${var.base_name}loganalytics"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 180
}

# COSMOS DB

resource "azurerm_cosmosdb_account" "cosmos_account" {
  name                             = "${var.base_name}cosmos"
  location                         = var.primary_location
  resource_group_name              = azurerm_resource_group.rg.name
  offer_type                       = "Standard"
  kind                             = "GlobalDocumentDB"
  multiple_write_locations_enabled = var.multi_region_write
  automatic_failover_enabled       = true
  ip_range_filter                  = local.api_apps_possible_ip_addresses

  consistency_policy {
    consistency_level = var.consistency_level
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
    zone_redundant    = var.availability_zones
  }

  dynamic "geo_location" {
    for_each = var.additional_locations
    content {
      location          = geo_location.value
      failover_priority = index(var.additional_locations, geo_location.value) + 1
      zone_redundant    = var.availability_zones
    }
  }
}

resource "azurerm_cosmosdb_sql_database" "inventory" {
  name                = "Inventory"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos_account.name
  autoscale_settings {
    max_throughput = var.database_max_throughput
  }
}

resource "azurerm_cosmosdb_sql_container" "products" {
  name                = "Products"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos_account.name
  database_name       = azurerm_cosmosdb_sql_database.inventory.name
  partition_key_paths = ["/id"]
  autoscale_settings {
    max_throughput = var.container_max_throughput
  }
}

resource "azurerm_monitor_diagnostic_setting" "cosmos_diagnostic_setting" {
  name                       = "cosmosdiagnosticsetting"
  target_resource_id         = azurerm_cosmosdb_account.cosmos_account.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  enabled_log {
    category = "DataPlaneRequests"
  }

  metric {
    category = "Requests"
  }
}

# KEY VAULT

resource "azurerm_key_vault" "key_vault" {
  name                = "${var.base_name}keyvault"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Get",
      "Set",
      "List"
    ]
  }

  dynamic "access_policy" {
    for_each = module.geode
    content {
      tenant_id = access_policy.value["api_tenant_id"]
      object_id = access_policy.value["api_principal_id"]
      key_permissions = [
        "Get",
      ]
      secret_permissions = [
        "Get",
      ]
    }
  }
}

resource "azurerm_key_vault_secret" "cosmos_connection_string" {
  name         = "cosmosConnectionString"
  value        = "AccountEndpoint=${azurerm_cosmosdb_account.cosmos_account.endpoint};AccountKey=${azurerm_cosmosdb_account.cosmos_account.primary_key};"
  key_vault_id = azurerm_key_vault.key_vault.id
}

# GEODE API

module "geode" {
  count               = length(local.allLocations)
  source              = "./internal_modules/geode"
  base_name           = var.base_name
  location            = local.allLocations[count.index]
  resource_group_name = azurerm_resource_group.rg.name
  app_service_sku     = var.app_service_sku
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

# CIRCULAR DEPENDENCIES

module "circular_dependencies" {
  count                                        = length(module.geode)
  source                                       = "./internal_modules/circular_dependencies"
  resource_group_name                          = azurerm_resource_group.rg.name
  api_management_name                          = module.geode[count.index].api_management_name
  function_app_name                            = module.geode[count.index].api_app_name
  instrumentation_key                          = module.geode[count.index].app_insights_instrumentation_key
  cosmos_connection_string_key_vault_secret_id = azurerm_key_vault_secret.cosmos_connection_string.id
  front_door_header_id                         = azurerm_cdn_frontdoor_profile.frontdoor.resource_guid
  entra_application_client_id                  = module.geode[count.index].entra_application_client_id
}
