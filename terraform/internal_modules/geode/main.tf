locals {
  service_name = "${var.base_name}${var.location}"
}

# API MANAGEMENT

resource "azurerm_api_management" "apim_service" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "Publisher"
  publisher_email     = "publisher@example.com"
  sku_name            = "Consumption_0"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_api_management_api" "inventory" {
  name                  = "Inventory"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.apim_service.name
  revision              = "1"
  display_name          = "Inventory"
  path                  = "inventory"
  protocols             = ["https"]
  service_url           = "https://${azurerm_windows_function_app.fxn_app.default_hostname}"
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "get_product_by_id" {
  operation_id        = "GetProductById"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = var.resource_group_name
  display_name        = "GetProductById"
  method              = "GET"
  url_template        = "/api/product/{id}"
  description         = "Retrieves Product by Id"

  response {
    status_code = 200
  }

  template_parameter {
    name     = "id"
    required = true
    type     = "string"
  }
}

resource "azurerm_api_management_api_operation" "get_products" {
  operation_id        = "GetProducts"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = var.resource_group_name
  display_name        = "GetProducts"
  method              = "GET"
  url_template        = "/api/products"
  description         = "Retrieves all Products"

  response {
    status_code = 200
  }
}

# Microsoft Entra ID

resource "azuread_application" "entra_application" {
  display_name = local.service_name
  web {
    redirect_uris = ["https://${local.service_name}.azurewebsites.net/.auth/login/aad/callback"]
    implicit_grant {
      access_token_issuance_enabled = true
    }
  }
}

# AZURE FUNCTION

resource "azurerm_application_insights" "fxn_app_insights" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

resource "azurerm_storage_account" "fxn_storage" {
  name                     = local.service_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "fxn_ase" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Windows"
  sku_name            = var.app_service_sku
}

resource "azurerm_windows_function_app" "fxn_app" {
  name                       = local.service_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = azurerm_service_plan.fxn_ase.id
  storage_account_name       = azurerm_storage_account.fxn_storage.name
  storage_account_access_key = azurerm_storage_account.fxn_storage.primary_access_key

  site_config {
    application_stack {
      dotnet_version              = "v8.0"
      use_dotnet_isolated_runtime = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  auth_settings_v2 {
    auth_enabled = true
    login {}
    active_directory_v2 {
      client_id            = azuread_application.entra_application.client_id
      tenant_auth_endpoint = "https://login.microsoftonline.com/${var.tenant_id}/v2.0/"
      allowed_identities   = [azurerm_api_management.apim_service.identity[0].principal_id]
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings,
      ftp_publish_basic_authentication_enabled,
      webdeploy_publish_basic_authentication_enabled
    ]
  }
}
