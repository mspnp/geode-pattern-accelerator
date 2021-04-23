using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Inventory.Models;
using System.Collections.Generic;
using System;

namespace Inventory.Functions
{
    public static class GetProducts
    {
        [FunctionName("GetProducts")]
        public static IActionResult Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = "products")] HttpRequest req,
            [CosmosDB(
                databaseName: "Inventory",
                collectionName: "Products",
                ConnectionStringSetting = "CosmosDBConnection",
                SqlQuery = "SELECT * FROM c")]
                IEnumerable<ProductDocument> retrievedProducts,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            return new OkObjectResult(retrievedProducts);
        }
    }
}
