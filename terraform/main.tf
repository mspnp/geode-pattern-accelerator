provider "azurerm" {
  features {}
}

locals {
  allLocations = concat([var.primaryLocation], var.additionalLocations)
  api_apps_possible_ip_addresses = [
    for geode in module.geode :
    geode.api_app_possible_ip_addresses
  ]
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "${var.baseName}-rg"
  location = var.primaryLocation
}

# FRONT DOOR

resource "azurerm_frontdoor" "frontdoor" {
  name                                         = "${var.baseName}frontdoor"
  location                                     = "global"
  resource_group_name                          = azurerm_resource_group.rg.name
  enforce_backend_pools_certificate_name_check = false

  backend_pool {
    name = "geodeAPIBackendPool"

    dynamic "backend" {
      for_each = module.geode
      content {
        host_header = split("https://", backend.value["api_management_gateway_url"])[1]
        address     = split("https://", backend.value["api_management_gateway_url"])[1]
        http_port   = 80
        https_port  = 443
      }
    }

    load_balancing_name = "defaultBackendPoolLoadBalancingSettings"
    health_probe_name   = "defaultBackendPoolHealthProbeSettings"
  }

  backend_pool_health_probe {
    name = "defaultBackendPoolHealthProbeSettings"
  }

  backend_pool_load_balancing {
    name = "defaultBackendPoolLoadBalancingSettings"
  }

  frontend_endpoint {
    name                              = "geodeAPIFrontendEndpoint"
    host_name                         = "${var.baseName}frontdoor.azurefd.net"
    custom_https_provisioning_enabled = false
  }

  routing_rule {
    name               = "geodeAPIRoutingRule"
    frontend_endpoints = ["geodeAPIFrontendEndpoint"]
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "geodeAPIBackendPool"
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "frontdoordiagnosticsetting" {
  name                       = "frontdoordiagnosticsetting"
  target_resource_id         = azurerm_frontdoor.frontdoor.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.loganalytics.id

  log {
    category = "FrontdoorAccessLog"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }
}

# LOG ANALYTICS

resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                = "${var.baseName}loganalytics"
  location            = var.primaryLocation
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 180
}

# COSMOS DB

resource "azurerm_cosmosdb_account" "cosmosaccount" {
  name                            = "${var.baseName}cosmos"
  location                        = var.primaryLocation
  resource_group_name             = azurerm_resource_group.rg.name
  offer_type                      = "Standard"
  kind                            = "GlobalDocumentDB"
  enable_multiple_write_locations = var.multiRegionWrite
  enable_automatic_failover       = true
  ip_range_filter                 = join(",", local.api_apps_possible_ip_addresses)

  consistency_policy {
    consistency_level = var.consistencyLevel
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
    zone_redundant    = var.availabilityZones
  }

  dynamic "geo_location" {
    for_each = var.additionalLocations
    content {
      location          = geo_location.value
      failover_priority = index(var.additionalLocations, geo_location.value) + 1
      zone_redundant    = var.availabilityZones
    }
  }
}

resource "azurerm_cosmosdb_sql_database" "inventory" {
  name                = "Inventory"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosaccount.name
  autoscale_settings {
    max_throughput = var.databaseMaxThroughput
  }
}

resource "azurerm_cosmosdb_sql_container" "products" {
  name                = "Products"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosaccount.name
  database_name       = azurerm_cosmosdb_sql_database.inventory.name
  partition_key_path  = "/id"
  autoscale_settings {
    max_throughput = var.containerMaxThroughput
  }
}

resource "azurerm_monitor_diagnostic_setting" "cosmosdiagnosticsetting" {
  name                       = "cosmosdiagnosticsetting"
  target_resource_id         = azurerm_cosmosdb_account.cosmosaccount.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.loganalytics.id

  log {
    category = "DataPlaneRequests"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  log {
    category = "MongoRequests"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  log {
    category = "QueryRuntimeStatistics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  log {
    category = "PartitionKeyStatistics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  log {
    category = "PartitionKeyRUConsumption"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  log {
    category = "ControlPlaneRequests"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }

  metric {
    category = "Requests"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 180
    }
  }
}

# KEY VAUlT

resource "azurerm_key_vault" "keyvault" {
  name                = "${var.baseName}keyvault"
  location            = var.primaryLocation
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "get",
      "set"
    ]
  }

  dynamic "access_policy" {
    for_each = module.geode
    content {
      tenant_id = access_policy.value["api_tenant_id"]
      object_id = access_policy.value["api_principal_id"]
      key_permissions = [
        "get",
      ]
      secret_permissions = [
        "get",
      ]
    }
  }
}

resource "azurerm_key_vault_secret" "cosmosconnectionstring" {
  name         = "cosmosConnectionString"
  value        = "AccountEndpoint=${azurerm_cosmosdb_account.cosmosaccount.endpoint};AccountKey=${azurerm_cosmosdb_account.cosmosaccount.primary_key};"
  key_vault_id = azurerm_key_vault.keyvault.id
}

# GEODE API

module "geode" {
  count              = length(local.allLocations)
  source             = "./internal_modules/geode"
  baseName           = var.baseName
  location           = local.allLocations[count.index]
  resourceGroupName  = azurerm_resource_group.rg.name
  appServicePlanTier = var.appServicePlanTier
  appServicePlanSize = var.appServicePlanSize
}

# AZURE FUNCTION APP SETTINGS

module "circular_dependencies" {
  count                                  = length(module.geode)
  source                                 = "./internal_modules/circular_dependencies"
  resourceGroupName                      = azurerm_resource_group.rg.name
  apiManagementName                      = module.geode[count.index].api_management_name
  functionAppName                        = module.geode[count.index].api_app_name
  instrumentationKey                     = module.geode[count.index].app_insights_instrumentation_key
  cosmosConnectionStringKeyVaultSecretId = azurerm_key_vault_secret.cosmosconnectionstring.id
  frontDoorHeaderId                      = azurerm_frontdoor.frontdoor.header_frontdoor_id
  azureADApplicationId                   = module.geode[count.index].azuread_application_id
}
