variable "baseName" {
  type        = string
  description = "The base name for created resources, used for tagging as a group."
}

variable "location" {
  type        = string
  description = "The Azure region in which to deploy API resources."
}

variable "resourceGroupName" {
  type        = string
  description = "The name of the Resource Group in which to deploy API resources."
}

variable "appServicePlanTier" {
  type        = string
  description = "Specifies the Azure Functions App Service plan pricing tier."
  default     = "Dynamic"
}

variable "appServicePlanSize" {
  type        = string
  description = "Specifies the Azure Functions App Service plan instance size tier."
  default     = "Y1"
}

locals {
  service_name = "${var.baseName}${var.location}"
}

# API MANAGEMENT

resource "null_resource" "apimservice" {
  provisioner "local-exec" {
    command = "az apim create --name ${local.service_name} -g ${var.resourceGroupName} -l ${var.location} --sku-name Consumption --publisher-email publisher@example.com --publisher-name Publisher"
  }
}

resource "null_resource" "apimservicemanagedidentity" {
  provisioner "local-exec" {
    command = "az apim update --name ${local.service_name} -g ${var.resourceGroupName} --enable-managed-identity true"
  }

  depends_on = [null_resource.apimservice]
}

resource "azurerm_api_management_api" "inventory" {
  name                  = "Inventory"
  resource_group_name   = var.resourceGroupName
  api_management_name   = local.service_name
  revision              = "1"
  display_name          = "Inventory"
  path                  = "inventory"
  protocols             = ["https"]
  service_url           = "https://${azurerm_function_app.fxnapp.default_hostname}"
  subscription_required = false

  depends_on = [null_resource.apimservice]
}

resource "azurerm_api_management_api_policy" "managedidentityapipolicy" {
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName

  xml_content = <<XML
<policies>
  <inbound>
      <authentication-managed-identity resource="${azuread_application.azuread.application_id}" />
  </inbound>
</policies>
XML
}

resource "azurerm_api_management_api_operation" "getproductbyid" {
  operation_id        = "GetProductById"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
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
  resource_group_name = var.resourceGroupName
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
  resource_group_name = var.resourceGroupName
  application_type    = "web"
}

resource "azurerm_storage_account" "fxnstorage" {
  name                     = local.service_name
  resource_group_name      = var.resourceGroupName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

resource "azurerm_app_service_plan" "fxnase" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resourceGroupName
  kind                = "functionapp"

  sku {
    tier = var.appServicePlanTier
    size = var.appServicePlanSize
  }
}

resource "azurerm_function_app" "fxnapp" {
  name                       = local.service_name
  location                   = var.location
  resource_group_name        = var.resourceGroupName
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

output "api_app_name" {
  value = azurerm_function_app.fxnapp.name
}

output "api_app_possible_ip_addresses" {
  value = azurerm_function_app.fxnapp.possible_outbound_ip_addresses
}

output "api_management_gateway_url" {
  value = "https://${local.service_name}.azure-api.net"
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.fxnappinsights.instrumentation_key
  sensitive = true
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.fxnappinsights.connection_string
  sensitive = true
}

output "api_tenant_id" {
  value     = azurerm_function_app.fxnapp.identity[0].tenant_id
  sensitive = true
}

output "api_principal_id" {
  value     = azurerm_function_app.fxnapp.identity[0].principal_id
  sensitive = true
}
