using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Inventory.Models;

namespace inventory_api.Functions
{
    public class GetProducts
    {
        private readonly ILogger<GetProducts> _logger;

        public GetProducts(ILogger<GetProducts> logger)
        {
            _logger = logger;
        }

        [Function("GetProducts")]
        public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = "products")] HttpRequest req,
            [CosmosDBInput(
                databaseName: "Inventory",
                containerName: "Products",
                Connection  = "CosmosDBConnection",
                SqlQuery = "SELECT * FROM c")] IEnumerable<ProductDocument> retrievedProducts)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            return new OkObjectResult(retrievedProducts);
        }
    }
}
