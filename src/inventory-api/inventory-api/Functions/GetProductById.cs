using inventory_api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace inventory_api.Functions
{
    public class GetProductById
    {
        private readonly ILogger<GetProducts> _logger;

        public GetProductById(ILogger<GetProducts> logger)
        {
            _logger = logger;
        }

        [Function("GetProductById")]
        public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = "product/{id}")] HttpRequest req,
            [CosmosDBInput(
                databaseName: "Inventory",
                containerName: "Products",
                Connection  = "CosmosDBConnection",
                Id = "{id}",
                PartitionKey = "{id}")] IEnumerable<ProductDocument> retrievedProducts)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            return new OkObjectResult(retrievedProducts);
        }
    }
}
