locals {
  service_name = "${var.base_name}${var.location}"
}

# API MANAGEMENT

resource "null_resource" "apimservice" {
  provisioner "local-exec" {
    command = "az apim create --name ${local.service_name} -g ${var.resource_group_name} -l ${var.location} --sku-name Consumption --publisher-email publisher@example.com --publisher-name Publisher"
  }
}

resource "null_resource" "apimservicemanagedidentity" {
  provisioner "local-exec" {
    command = "az apim update --name ${local.service_name} -g ${var.resource_group_name} --enable-managed-identity true"
  }

  depends_on = [null_resource.apimservice]
}

resource "azurerm_api_management_api" "inventory" {
  name                  = "Inventory"
  resource_group_name   = var.resource_group_name
  api_management_name   = local.service_name
  revision              = "1"
  display_name          = "Inventory"
  path                  = "inventory"
  protocols             = ["https"]
  service_url           = "https://${azurerm_function_app.fxnapp.default_hostname}"
  subscription_required = false

  depends_on = [null_resource.apimservice]
}

resource "azurerm_api_management_api_operation" "getproductbyid" {
  operation_id        = "GetProductById"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
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

resource "azurerm_api_management_api_operation" "getproducts" {
  operation_id        = "GetProducts"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resource_group_name
  display_name        = "GetProducts"
  method              = "GET"
  url_template        = "/api/products"
  description         = "Retrieves all Products"

  response {
    status_code = 200
  }
}

# AAD

resource "azuread_application" "azuread" {
  display_name               = local.service_name
  reply_urls                 = ["https://${local.service_name}.azurewebsites.net/.auth/login/aad/callback"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}


# AZURE FUNCTION

resource "azurerm_application_insights" "fxnappinsights" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

resource "azurerm_storage_account" "fxnstorage" {
  name                     = local.service_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

resource "azurerm_app_service_plan" "fxnase" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "functionapp"

  sku {
    tier = var.app_service_plan_tier
    size = var.app_service_plan_size
  }
}

resource "azurerm_function_app" "fxnapp" {
  name                       = local.service_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = azurerm_app_service_plan.fxnase.id
  storage_account_name       = azurerm_storage_account.fxnstorage.name
  storage_account_access_key = azurerm_storage_account.fxnstorage.primary_access_key
  version                    = "~3"
  enable_builtin_logging     = false

  lifecycle {
    ignore_changes = [
      app_settings
    ]
  }

  identity {
    type = "SystemAssigned"
  }

  auth_settings {
    enabled = true
    active_directory {
      client_id = azuread_application.azuread.application_id
    }
  }
}
