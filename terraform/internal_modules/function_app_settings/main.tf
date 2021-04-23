variable "instrumentationKey" {
  type        = string
  description = "The Application Insights instrumentation key"
}

variable "functionAppName" {
  type        = string
  description = "The name of the Azure Function app"
}

variable "cosmosConnectionStringKeyVaultSecretId" {
  type        = string
  description = "The ID for the Key Vault secret which stores the connection string for the Cosmos DB instance"
}

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

resource "local_file" "fxnappsettings" {
  sensitive_content = jsonencode(local.function_app_settings)
  filename          = "./app_settings/${var.functionAppName}_app_settings.json"
}
