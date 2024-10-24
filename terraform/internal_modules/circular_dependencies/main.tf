// API POLICY

resource "azurerm_api_management_named_value" "frontdoor_header" {
  name                = "frontDoorHeader"
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "frontDoorHeader"
  value               = "X-Azure-FDID"
}

resource "azurerm_api_management_named_value" "frontdoor_header_value" {
  name                = "frontDoorHeaderValue"
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "frontDoorHeaderValue"
  value               = var.front_door_header_id
}

resource "azurerm_api_management_api_policy" "api_policy" {
  api_name            = "Inventory"
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
      <authentication-managed-identity resource="${var.entra_application_client_id}" />
      <check-header name="{{frontDoorHeader}}" failed-check-httpcode="401" failed-check-error-message="Not authorized" ignore-case="false">
        <value>{{frontDoorHeaderValue}}</value>
      </check-header>
      <base />
  </inbound>
</policies>
XML

  depends_on = [azurerm_api_management_named_value.frontdoor_header, azurerm_api_management_named_value.frontdoor_header_value]
}

// FUNCTION APP SETTINGS

locals {
  function_app_settings = [
    {
      name        = "APPINSIGHTS_INSTRUMENTATIONKEY"
      value       = var.instrumentation_key
      slotSetting = false
    },
    {
      name        = "FUNCTIONS_EXTENSION_VERSION"
      value       = "~4"
      slotSetting = false
    },
    {
      name        = "FUNCTIONS_WORKER_RUNTIME"
      value       = "dotnet-isolated"
      slotSetting = false
    },
    {
      name        = "CosmosDBConnection"
      value       = "@Microsoft.KeyVault(SecretUri=${var.cosmos_connection_string_key_vault_secret_id})"
      slotSetting = false
    }
  ]
}

resource "null_resource" "fxn_app_settings" {
  provisioner "local-exec" {
    command = "az functionapp config appsettings set -g ${var.resource_group_name} -n ${var.function_app_name} --settings ${jsonencode(local.function_app_settings)}"
  }
}

