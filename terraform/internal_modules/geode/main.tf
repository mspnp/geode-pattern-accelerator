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

variable "appServicePlanTier" {
  type        = string
  description = "Specifies the Azure Function's App Service plan pricing tier."
  default     = "Dynamic"
}

variable "appServicePlanSize" {
  type        = string
  description = "Specifies the Azure Function's App Service plan instance size tier."
  default     = "Y1"
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
  service_url           = "https://${azurerm_function_app.fxnapp[0].default_hostname}"
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

# AZURE FUNCTION

resource "azurerm_application_insights" "fxnappinsights" {
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

output "api_app_name" {
  value = azurerm_function_app.fxnapp[0].name
}

output "api_app_possible_ip_addresses" {
  value = azurerm_function_app.fxnapp[0].possible_outbound_ip_addresses
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
  value     = azurerm_function_app.fxnapp[0].identity[0].tenant_id
  sensitive = true
}

output "api_principal_id" {
  value     = azurerm_function_app.fxnapp[0].identity[0].principal_id
  sensitive = true
}
