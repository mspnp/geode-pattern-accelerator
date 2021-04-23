variable "instrumentationKey" {
  type        = string
  description = "The Application Insights instrumentation key"
}

variable "appInsightsConnectionString" {
  type        = string
  description = "The Application Insights instrumentation key"
}
variable "webAppName" {
  type        = string
  description = "The name of the Azure Function app"
}

locals {
  web_app_settings = [
    {
      name        = "APPINSIGHTS_INSTRUMENTATIONKEY"
      value       = var.instrumentationKey
      slotSetting = false
    },
    {
      name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
      value       = var.appInsightsConnectionString
      slotSetting = false
    },
    {
      name        = "ApplicationInsightsAgent_EXTENSION_VERSION"
      value       = "~2"
      slotSetting = false
    },
    {
      name        = "XDT_MicrosoftApplicationInsights_Mode"
      value       = "default"
      slotSetting = false
    }
  ]
}

resource "local_file" "appserviceappsettings" {
  sensitive_content = jsonencode(local.web_app_settings)
  filename          = "./app_settings/${var.webAppName}_app_settings.json"
}
