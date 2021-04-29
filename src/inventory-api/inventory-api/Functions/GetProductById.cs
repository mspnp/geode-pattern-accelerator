using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Inventory.Models;

namespace Inventory.Functions
{
    public static class GetProductById
    {
        [FunctionName("GetProductById")]
        public static IActionResult Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "product/{id}")] HttpRequest req,
            [CosmosDB(
                databaseName: "Inventory",
                collectionName: "Products",
                ConnectionStringSetting = "CosmosDBConnection",
                Id = "{id}",
                PartitionKey = "{id}")] ProductDocument retrievedProduct,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            return new OkObjectResult(retrievedProduct);
        }
    }
}
