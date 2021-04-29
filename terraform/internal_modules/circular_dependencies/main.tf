// API POLICY

resource "azurerm_api_management_named_value" "frontdoorheader" {
  name                = "frontDoorHeader"
  api_management_name = var.apiManagementName
  resource_group_name = var.resourceGroupName
  display_name        = "frontDoorHeader"
  value               = "X-Azure-FDID"
}

resource "azurerm_api_management_named_value" "frontdoorheadervalue" {
  name                = "frontDoorHeaderValue"
  api_management_name = var.apiManagementName
  resource_group_name = var.resourceGroupName
  display_name        = "frontDoorHeaderValue"
  value               = var.frontDoorHeaderId
}

resource "azurerm_api_management_api_policy" "apipolicy" {
  api_name            = "Inventory"
  api_management_name = var.apiManagementName
  resource_group_name = var.resourceGroupName

  xml_content = <<XML
<policies>
  <inbound>
      <authentication-managed-identity resource="${var.azureADApplicationId}" />
      <check-header name="{{frontDoorHeader}}" failed-check-httpcode="401" failed-check-error-message="Not authorized" ignore-case="false">
        <value>{{frontDoorHeaderValue}}</value>
      </check-header>
  </inbound>
</policies>
XML

  depends_on = [azurerm_api_management_named_value.frontdoorheader, azurerm_api_management_named_value.frontdoorheadervalue]
}

// FUNCTION APP SETTINGS

locals {
  function_app_settings = [
    {
      name        = "APPINSIGHTS_INSTRUMENTATIONKEY"
      value       = var.instrumentationKey
      slotSetting = false
    },
    {
      name        = "FUNCTIONS_EXTENSION_VERSION"
      value       = "~3"
      slotSetting = false
    },
    {
      name        = "FUNCTIONS_WORKER_RUNTIME"
      value       = "dotnet"
      slotSetting = false
    },
    {
      name        = "CosmosDBConnection"
      value       = "@Microsoft.KeyVault(SecretUri=${var.cosmosConnectionStringKeyVaultSecretId})"
      slotSetting = false
    }
  ]
}

resource "null_resource" "fxnappsettings" {
  provisioner "local-exec" {
    command = "az functionapp config appsettings set -g ${var.resourceGroupName} -n ${var.functionAppName} --settings ${jsonencode(local.function_app_settings)}"
  }
}

