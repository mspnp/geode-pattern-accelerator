# Geode Pattern Accelerator

The accelerator is designed to help developers with Azure Functions based APIs that utilize Cosmos DB as a data store to implement the [geode pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/geodes) by deploying their API to geodes in distributed Azure regions.

![Geode Pattern](./images/GeodeWorldMap.png)

The repository contains Terraform code that deploys geodes to a configurable set of Azure regions, each containing an Azure Function App and API Management instance that fronts it. It also deploys a Cosmos DB account with read/write regions in each of the geode locations and an Azure Front Door that load balances between the regional API deployments. Each piece of the larger architecture is deployed with dedicated monitoring resources and security measures.

The accelerator can be used with any Azure Functions based API, but also supplies a basic .NET Inventory API as a starting place for new projects.

## Architecture Details

Applying the files in the `./terraform` directory creates a series of resources in a new resource group. In each of the locations supplied via Terraform parameter, a Consumption tier API Management instance is deployed with an Azure Functions backend. The API Management instance has an API and Operations that exactly match the endpoints exposed by the Azure Function App. An Azure Front Door is deployed globally and is configured with routing rules that allow it to distribute traffic between the API Management instances. The Front Door serves as the single point of entry for the API.

Each geode also receives a dedicated Microsoft Entra application that is used to secure the geode's Function App. The API Management instance is deployed with Managed Identity and contains an `authentication-managed-identity` policy that allows it to call the Azure Functions. Traffic to the Azure Functions is thus restricted to the API Management instance in its geode. Each API Management instance is also secured so that it only accepts requests from Azure Front Door. Relevant secrets are stored in a single Key Vault instance which supports the entire resource group.

The Terraform code also creates a Cosmos DB instance with a database and containers that are necessary for the Azure Functions. Each of the locations supplied via Terraform parameter are added as read regions. Optionally, the files can be applied with multi-region write enabled, deploying each of the same read regions with write capabilities. Other important properties on the Cosmos DB like maximum throughput on the database and containers, consistency level, etc. can also be easily supplied via Terraform parameter. Traffic is restricted so that the only entities able to run Cosmos DB queries are the set of Azure Functions in the various geodes.

Monitoring resources are deployed to each of the resources in the larger API architecture, where possible. A single Log Analytics workspace is deployed to the resource group and is configured to capture logs from Front Door, Cosmos DB, Azure Functions, Key Vault, and Cosmos DB. Each Azure Function App is also deployed with a dedicated Application Insights that is used to collect and query its log, performance, and error data. Application Insights reduces throughput when applied to an API Management instance and the Consumption tier does not currently support Log Analytics, so monitoring has been omitted for API Management.

The top level resources deployed to the resource group _once_ are as follows:

- Front Door
- Cosmos DB
- Key Vault
- Log Analytics

The top level resources deployed _to each geode_ are as follows:

- API Management
- App Service Plan
- Azure Functions
- Microsoft Entra ID
- Application Insights
- Storage Account

## Use With Example Inventory API

The [/src](./src) directory contains a basic API that serves as an example and place for developers to get started with the accelerator. The Inventory API is designed to work with a Cosmos DB instance with an Inventory database and Products container. The API contains two endpoints, GetProducts and GetProductById, which retrieve all Products and a specific Product, respectively, from the Products container. The endpoints themselves utilize Cosmos DB input bindings for Azure Functions and simply return the retrieved result, without any additional C# logic.

Ensure your subscription_id is set within the `provider` block in [main.tf](./terraform/main.tf), then navigate to the [/terraform](./terraform) directory and initialize the project:

```dotnetcli
terraform init
```

Rename the [`sample.terraform.tfvars`](./terraform/sample.terraform.tfvars) to `terraform.tfvars` and update the parameter values accordingly.

Plan, and then apply the execution plan, supplying the parameter values via the `terraform.tfvars` file:

```dotnetcli
terraform apply -var-file="terraform.tfvars"
```

Finally, navigate to the [/terraform/scripts](./terraform/scripts) directory and run `publishfunctions.sh`, passing in the relative paths for the directories that contain the Terraform and Azure Functions projects. The shell script ingests the outputs from the `terraform apply` and deploys the API code to each Azure Function App:

_Note: The script requires that [Azure Functions Core Tools 4.x](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Ccsharp%2Cbash#install-the-azure-functions-core-tools) be installed on the machine._

```dotnetcli
publishfunctions.sh ../ ../../src/inventory-api/inventory-api
```

Once the script exits, test the API endpoints in the Azure Front Door, using the `frontdoor_hostname` from the Terraform outputs (`https://<frontdoor_hostname>/inventory/api/products` and `https://<frontdoor_hostname>/inventory/api/product/{id}`).

## Use With Your Own API

The accelerator contains a .NET Azure Functions based Inventory API ([/src/inventory-api](./src/inventory-api)) that deals with storage and retrieval of Product entities in Cosmos DB. The project contains two Functions, GetProducts and GetProductById, which retrieve all Products and a specific Product, respectively, from the Products container in an Inventory database in a Cosmos DB.

Assuming you have an Azure Functions based API that uses Cosmos DB as a data store, the Inventory API can be deleted from the repository entirely and a new Azure Functions project can be moved into the repo. In order for the accelerator to work with your API, the Terraform code will need to be updated in a few key places.

The Cosmos DB database and container resources are declared on line 139 of [main.tf](./terraform/main.tf). Update the "inventory" database and "products" container with the appropriate names and partition keys:

```terraform
resource "azurerm_cosmosdb_sql_database" "inventory" {
  name                = "Inventory"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosaccount.name
  autoscale_settings {
    max_throughput = var.database_max_throughput
  }
}

resource "azurerm_cosmosdb_sql_container" "products" {
  name                = "Products"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosaccount.name
  database_name       = azurerm_cosmosdb_sql_database.inventory.name
  partition_key_paths = ["/id"]
  autoscale_settings {
    max_throughput = var.container_max_throughput
  }
}
```

The API Management API(s) and Operations will need to be updated to match the endpoints in your API.

On line 20 of [main.tf](./terraform/internal_modules/geode/main.tf) in the geode module, the "inventory" API is declared with path, protocols, etc. specified:

```terraform
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
```

Rename the API and update its properties to fit your API's needs.

The two endpoints, GetProducts and GetProductById, are declared on line 35:

```terraform
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
```

Update the Operations to match the endpoints in your API, ensuring that the url template matches exactly so requests are properly routed.

The Inventory API project relies on a `CosmosDBConnection` application setting, stored in the [local.settings.json](./src/inventory-api/inventory-api/sample.local.settings.json) file. Line 42 in the [circular_dependencies module](./terraform/internal_modules/circular_dependencies/main.tf) declares a `function_app_settings` array with the necessary key value pairs from the Inventory API's `local.settings.json` file:

```terraform
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
```

Update the array with the appropriate settings from your API's `local.settings.json` file.

At this point, the project has been updated to fit the new API and can now be used to globally distribute its deployment. Ensure your subscription_id is set within the `provider` block in [main.tf](./terraform/main.tf), then navigate to the [/terraform](./terraform) directory and initialize the project:

```dotnetcli
terraform init
```

Rename the [`sample.terraform.tfvars`](./terraform/sample.terraform.tfvars) to `terraform.tfvars` and update the parameter values accordingly.

Plan, and then apply the execution plan, supplying the parameter values via the `terraform.tfvars` file:

```dotnetcli
terraform apply -var-file="terraform.tfvars"
```

Finally, navigate to the [/terraform/scripts](./terraform/scripts) directory and run publishfunctions.sh, passing in the relative paths for the directories that contain the Terraform and Azure Functions projects. The shell script ingests the outputs from the `terraform apply` and deploys the API code to each Azure Function App:

```dotnetcli
publishfunctions.sh <TERRAFORM_DIRECTORY_RELATIVE_PATH> <FUNCTION_APP_DIRECTORY_RELATIVE_PATH>
```

Once the script exits, test the API endpoints in the Azure Front Door, using the `frontdoor_hostname` from the Terraform outputs (`https://<frontdoor_hostname>/inventory/api/products` and `https://<frontdoor_hostname>/inventory/api/product/{id}`).

## Terraform Parameters

| Parameter              | DataType | Required | Description                                                                                                                            |
| ---------------------- | -------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| base_name               | string   | true     | The base name for created resources, used for tagging as a group.                                                                      |
| primary_location        | string   | true     | The Azure region in which to deploy the Resource Group as well as Cosmos DB, API, and Key Vault resources.                             |
| additional_locations    | string   | true     | The additional Azure regions in which to deploy API resources.                                                                         |
| database_max_throughput  | integer  | false    | The maximum throughput of the SQL database (RU/s). Must be between 100,000 and 1,000,000. Must be set in increments of 1,000.          |
| container_max_throughput | integer  | false    | The maximum throughput of the SQL container (RU/s). Must be between 10,000 and 100,000. Must be set in increments of 1,000.            |
| consistency_level       | string   | false    | The Consistency Level to use for the CosmosDB Account - can be either BoundedStaleness, Eventual, Session, Strong or ConsistentPrefix. |
| availability_zones      | boolean  | false    | Should zone redundancy be enabled for the Cosmos DB regions?                                                                           |
| multi_region_write       | boolean  | false    | Enable multi-master support for the Cosmos DB account.                                                                                 |
| app_service_sku     | string   | false    | Specifies the Azure Functions App Service SKU.                                                                           |
| front_door_sku     | string   | false    | Specifies the Azure Front Door SKU.                                                                     |

## Security

All services in the API architecture are secure, aside from the Azure Front Door. The Cosmos DB is inaccessible to all entities except the Azure Function Apps through IP restriction. The Azure Functions are deployed alongside a dedicated Microsoft Entra application that is used to restrict access to the Function endpoints. The endpoints are only accessible via the API Management instance in the same geode, which have Managed Identity and a corresponding `authentication-managed-identity` policy that allow it to authorize requests to the Azure Functions backend. Each API Management instance in the created resource group contains additional policies that make it inaccessible from all origins except the Azure Front Door. Front Doors are created with a unique ID that is attached to all requests to its backend pools via headers. The API Management API entities contain policies that check for the unique ID in the request headers and return 401s if it is not present.

The only accessible ingress point for the API is the Azure Front Door. The accelerator is designed to deploy the Front Door without security measures in order for you to add the appropriate ones for your needs. Azure Front Door is deployed alongside a [Front Door specific Web Application Firewall](https://learn.microsoft.com/azure/web-application-firewall/afds/afds-overview) (WAF). WAF policies should be added to the Front Door in the [main.tf](./terraform/main.tf) file via an [azurerm_cdn_frontdoor_firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_firewall_policy) resource and can secure the API from a number of vulnerabilities, provide custom access, rate limit, and more.

## Monitoring

The [/monitoring](./monitoring) directory contains Kusto queries that can be run against the different services within the API architecture. As previously mentioned, the global and geode-specific resources are configured to stream logs to Log Analytics and the Azure Functions are additionally deployed with a corresponding Application Insights instance. The queries each contain a `cluster()` function that connects to these monitoring resources and must be updated with the `baseName` value provided earlier as a Terraform parameter.

The following tables list the provided queries with a brief description:

### Front Door

| Kusto Query                                                                                        | Description                                                                                                             |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| [backend_errors.kql](./monitoring/front_door/backend_errors.kql)                                   | Displays the number of errors thrown by each backend in the Front Door's backend pool over a period of time.            |
| [incoming_requests_by_ip_address.kql](./monitoring/front_door/incoming_requests_by_ip_address.kql) | Displays the number of incoming requests from each IP address over a period of time.                                    |
| [requests_per_second.kql](./monitoring/front_door/requests_per_second.kql)                         | Displays the requests per second handled by the Front Door over a period of time.                                       |
| [routed_requests_by_backend_host.kql](./monitoring/front_door/routed_requests_by_backend_host.kql) | Displays the number of incoming requests routed to each backend in the Front Door's backend pool over a period of time. |

### Azure Functions

| Kusto Query                                                                                   | Description                                                                                                    |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| [function_instance_scaleout.kql](./monitoring/azure_functions/function_instance_scaleout.kql) | Displays the number of instances the Function App scaled to over a period of time.                             |
| [overall_response_duration.kql](./monitoring/azure_functions/overall_response_duration.kql)   | Displays the minimum, maximum, average, and percentile duration data over a period of time for all requests.   |
| [read_response_duration.kql](./monitoring/azure_functions/read_response_duration.kql)         | Displays the minimum, maximum, average, and percentile duration data over a period of time for read requests.  |
| [response_codes.kql](./monitoring/azure_functions/response_codes.kql)                         | Displays the count for each response code returned from the Function App over a period of time.                |
| [total_requests.kql](./monitoring/azure_functions/total_requests.kql)                         | Displays the total number of requests handled by the Function App over a period of time.                       |
| [write_response_duration.kql](./monitoring/azure_functions/write_response_duration.kql)       | Displays the minimum, maximum, average, and percentile duration data over a period of time for write requests. |

### Cosmos DB

| Kusto Query                                                                           | Description                                                                                                    |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| [consumed_rus.kql](./monitoring/cosmos_db/consumed_rus.kql)                           | Displays the consumed RUs for the Cosmos DB over a period of time.                                             |
| [read_operation_duration.kql](./monitoring/cosmos_db/read_operation_duration.kql)     | Displays the minimum, maximum, average, and percentile duration data over a period of time for read requests.  |
| [total_failed_requests.kql](./monitoring/cosmos_db/total_failed_requests.kql)         | Displays the total number of failed requests over a period of time.                                            |
| [total_read_requests.kql](./monitoring/cosmos_db/total_read_requests.kql)             | Displays the total number of read requests over a period of time.                                              |
| [total_successful_requests.kql](./monitoring/cosmos_db/total_successful_requests.kql) | Displays the total number of successful requests over a period of time.                                        |
| [total_throttled_requests.kql](./monitoring/cosmos_db/total_throttled_requests.kql)   | Displays the total number of throttled requests over a period of time.                                         |
| [total_write_requests.kql](./monitoring/cosmos_db/total_write_requests.kql)           | Displays the total number of write requests over a period of time.                                             |
| [write_operation_duration.kql](./monitoring/cosmos_db/write_operation_duration.kql)   | Displays the minimum, maximum, average, and percentile duration data over a period of time for write requests. |

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
