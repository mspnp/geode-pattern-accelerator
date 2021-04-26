# Geode Pattern Accelerator

The accelerator is designed to help developers with Azure Function based APIs that utilize Cosmos DB to implement the geode pattern by deploying their API to geodes in distributed Azure regions.

![Geode Pattern](./images/GeodeWorldMap.png)

The repository contains Terraform code that deploys geodes to a configurable set of Azure regions, each containing an Azure Function App and API Management instance that fronts it. It also deploys a Cosmos DB account with read/write regions in each of the geode locations and an Azure Front Door that load balances between the regional API deployments. Each piece of the larger architecture is deployed with dedicated monitoring resources and security measures.

The accelerator can be used with any Azure Function based API, but also supplies a basic .NET Inventory API as a starting place for new projects.

## Architecture Details

Applying the files in the terraform directory creates a series of resources. In each of the

## Use With Your Own API

The accelerator contains a .NET Azure Function based API ([/src/inventory-api](./src/inventory-api)) that deals with storage and retrieval of Product entities in Cosmos DB. The project contains two Functions - GetProducts and GetProductById, which retrieve all Products and a specific Product, respectively, from the Products table in an Inventory database in a Cosmos DB.

The API can be deleted from the repository entirely and a new Azure Function project should be moved into the project. In order for the accelerator to work with your API, the terraform code will need to be updated in a few key places.

The Cosmos DB database and container resources are declared on line 223 of [main.tf](./terraform/main.tf), . Update the "inventory" database and "products" container to have the appropriate names and partition keys:

```terraform
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
```

The API Management API(s) and Operations will need to be updated to match the endpoints in your API.

On line 48, the API is named 'Inventory' with path, protocols, etc. specified:

```terraform
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
```

Rename the API and update its properties to fit your API's needs.

The two endpoints, GetProducts and GetProductById, are declared on line 76:

```terraform
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
```

Update the Operations to match the endpoints in your API, ensuring that the url template matches exactly so requests are properly routed.

Alternatively, the API definition can be supplied via Open API spec. Rather than declare the Operation resources, the only entity that needs to be supplied is the API itself, this time with an `import` block pointing to the file.

```terraform
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

  import {
    content_format = "swagger-link-json"
    content_value  = "http://xxxx.azurewebsites.net/?format=json"
  }

  depends_on = [null_resource.apimservice]
}
```

The Inventory API project relies on a `CosmosDBConnection` application setting, stored in the [local.settings.json](./src/inventory-api/sample.local.settings.json) file. Line 17 in the [function_app_settings module](./terraform/internal_modules/function_app_settings/main.tf) declares a `function_app_settings` array with the necessary key value pairs from the Inventory API's local.settings.json file. Update the array with the appropriate settings from your API's local.settings.json file.

At this point, the project has been updated to fit the new API and can now be used to globally distribute its deployment. Navigate to the terraform directory ([/terraform](./terraform)) and initialize the project:

```dotnetcli
terraform init
```

Plan, and then apply the execution plan, supplying the appropriate values for your needs for each parameter:

```dotnetcli
terraform apply -var 'baseName=xxxxx' -var 'primaryLocation=xxxxx' -var 'additionalLocations=[\"xxxxx\"]' -var 'appServicePlanTier=xxxxx' -var 'appServicePlanSize=xxxxx' -var 'databaseMaxThroughput=xxxxx' -var 'containerMaxThroughput=xxxxx' -var 'consistencyLevel=xxxxx' -var 'availabilityZones=xxxxx' -var 'multiRegionWrite=xxxxx'
```

Finally, deploy your Azure Function code to each of the Function apps in the newly created resource group and test the API endpoints in the Azure Front Door.

## Selecting Terraform Parameter Values

**baseName**

**primaryLocation**

**additionalLocations**

**appServicePlanTier**

**appServicePlanSize**

**databaseMaxThroughput**

**containerMaxThroughput**

**consistencyLevel**

**availabilityZones**

**multiRegionWrite**

## Gotchas

- function settings are outputted as file
- give script that loops through apps and deploys function settings
