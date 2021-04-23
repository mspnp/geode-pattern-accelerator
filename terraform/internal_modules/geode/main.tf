variable "baseName" {
  type        = string
  description = "The root of base name for created resources, used for tagging as a group"
}

variable "location" {
  type        = string
  description = "The Azure region in which to deploy API resources"
}

variable "resourceGroupName" {
  type        = string
  description = "The name of the Resource Group in which to deploy API resources"
}

variable "apiType" {
  type        = string
  description = "The type of API service deployed into each geode - can be either AzureFunction or AzureAppService"
  default     = "AzureFunction"
  validation {
    condition     = var.apiType == "AzureFunction" || var.apiType == "AzureAppService"
    error_message = "Variable apiType must be either AzureFunction or AzureAppService."
  }
}

variable "appServicePlanTier" {
  type        = string
  description = "Specifies the App Service plan's pricing tier."
  default     = "Standard"
}

variable "appServicePlanSize" {
  type        = string
  description = "Specifies the App Service plan's instance size tier."
  default     = "S1"
}

locals {
  service_name = "${var.baseName}${var.location}"
}

# API MANAGEMENT

resource "null_resource" "apimservice" {
  provisioner "local-exec" {
    command = "az apim create --name ${local.service_name} -g ${var.resourceGroupName} -l ${var.location} --sku-name Consumption --publisher-email publisher@example.com --publisher-name Publisher --tags project=cnae-load-testing resource-base-name=${var.baseName}"
  }
}

resource "azurerm_api_management_api" "inventory" {
  name                  = "Inventory"
  resource_group_name   = var.resourceGroupName
  api_management_name   = local.service_name
  revision              = "1"
  display_name          = "Inventory"
  path                  = "inventory"
  protocols             = ["https"]
  service_url           = var.apiType == "AzureFunction" ? "https://${azurerm_function_app.fxnapp[0].default_hostname}" : "https://${azurerm_app_service.appserviceapp[0].default_site_hostname}"
  subscription_required = false

  depends_on = [null_resource.apimservice]
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

resource "azurerm_api_management_api_operation" "getallproducts" {
  operation_id        = "GetAllProducts"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
  display_name        = "GetAllProducts"
  method              = "GET"
  url_template        = "/api/products"
  description         = "Retrieves all Product Ids"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation" "updateinventory" {
  operation_id        = "UpdateInventory"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
  display_name        = "UpdateInventory"
  method              = "POST"
  url_template        = "/api/product/{id}/inventory"
  description         = "Update units available for a Product"

  response {
    status_code = 200
  }

  template_parameter {
    name     = "id"
    required = true
    type     = "string"
  }
}

resource "azurerm_api_management_api_operation" "getwarehousebyid" {
  operation_id        = "GetWarehouseById"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
  display_name        = "GetWarehouseById"
  method              = "GET"
  url_template        = "/api/warehouse/{id}"
  description         = "Retrieves Warehouse by Id"

  response {
    status_code = 200
  }

  template_parameter {
    name     = "id"
    required = true
    type     = "string"
  }
}

resource "azurerm_api_management_api_operation" "getorderbyid" {
  operation_id        = "GetOrderById"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
  display_name        = "GetOrderById"
  method              = "GET"
  url_template        = "/api/order/{id}"
  description         = "Retrieves Order by Id"

  response {
    status_code = 200
  }

  template_parameter {
    name     = "id"
    required = true
    type     = "string"
  }
}

resource "azurerm_api_management_api_operation" "createorder" {
  operation_id        = "CreateOrder"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
  display_name        = "CreateOrder"
  method              = "POST"
  url_template        = "/api/order"
  description         = "Creates Order"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation" "cancelorder" {
  operation_id        = "CancelOrder"
  api_name            = azurerm_api_management_api.inventory.name
  api_management_name = local.service_name
  resource_group_name = var.resourceGroupName
  display_name        = "CancelOrder"
  method              = "POST"
  url_template        = "/api/order/{id}/cancel"
  description         = "Cancels Order"

  response {
    status_code = 200
  }

  template_parameter {
    name     = "id"
    required = true
    type     = "string"
  }
}

# AZURE FUNCTION/AZURE APP SERVICE

resource "azurerm_application_insights" "apiappinsights" {
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resourceGroupName
  application_type    = "web"

  tags = {
    project            = "cnae-load-testing"
    resource-base-name = var.baseName
  }
}

resource "azurerm_storage_account" "fxnstorage" {
  count                    = var.apiType == "AzureFunction" ? 1 : 0
  name                     = local.service_name
  resource_group_name      = var.resourceGroupName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  tags = {
    project            = "cnae-load-testing"
    resource-base-name = var.baseName
  }
}

resource "azurerm_app_service_plan" "fxnase" {
  count               = var.apiType == "AzureFunction" ? 1 : 0
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resourceGroupName
  kind                = "functionapp"

  sku {
    tier = var.appServicePlanTier
    size = var.appServicePlanSize
  }

  tags = {
    project            = "cnae-load-testing"
    resource-base-name = var.baseName
  }
}

resource "azurerm_function_app" "fxnapp" {
  count                      = var.apiType == "AzureFunction" ? 1 : 0
  name                       = local.service_name
  location                   = var.location
  resource_group_name        = var.resourceGroupName
  app_service_plan_id        = azurerm_app_service_plan.fxnase[0].id
  storage_account_name       = azurerm_storage_account.fxnstorage[0].name
  storage_account_access_key = azurerm_storage_account.fxnstorage[0].primary_access_key
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

  tags = {
    project            = "cnae-load-testing"
    resource-base-name = var.baseName
  }
}

resource "azurerm_app_service_plan" "appservicease" {
  count               = var.apiType == "AzureAppService" ? 1 : 0
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resourceGroupName
  kind                = "windows"

  sku {
    tier = var.appServicePlanTier
    size = var.appServicePlanSize
  }

  tags = {
    project            = "cnae-load-testing"
    resource-base-name = var.baseName
  }
}

resource "azurerm_app_service" "appserviceapp" {
  count               = var.apiType == "AzureAppService" ? 1 : 0
  name                = local.service_name
  location            = var.location
  resource_group_name = var.resourceGroupName
  app_service_plan_id = azurerm_app_service_plan.appservicease[0].id

  lifecycle {
    ignore_changes = [
      app_settings
    ]
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    project            = "cnae-load-testing"
    resource-base-name = var.baseName
  }
}

output "api_app_name" {
  value = var.apiType == "AzureFunction" ? azurerm_function_app.fxnapp[0].name : azurerm_app_service.appserviceapp[0].name
}

output "api_app_possible_ip_addresses" {
  value = var.apiType == "AzureFunction" ? azurerm_function_app.fxnapp[0].possible_outbound_ip_addresses : azurerm_app_service.appserviceapp[0].possible_outbound_ip_addresses
}

output "api_management_gateway_url" {
  value = "https://${local.service_name}.azure-api.net"
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.apiappinsights.instrumentation_key
  sensitive = true
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.apiappinsights.connection_string
  sensitive = true
}

output "api_tenant_id" {
  value     = var.apiType == "AzureFunction" ? azurerm_function_app.fxnapp[0].identity[0].tenant_id : azurerm_app_service.appserviceapp[0].identity[0].tenant_id
  sensitive = true
}

output "api_principal_id" {
  value     = var.apiType == "AzureFunction" ? azurerm_function_app.fxnapp[0].identity[0].principal_id : azurerm_app_service.appserviceapp[0].identity[0].principal_id
  sensitive = true
}
