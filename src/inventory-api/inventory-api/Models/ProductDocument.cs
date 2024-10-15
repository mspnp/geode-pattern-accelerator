using Newtonsoft.Json;

namespace Inventory.Models
{
    public class ProductDocument
    {
        [JsonProperty("id")]
        public Guid Id { get; set; }

        [JsonProperty("description")]
        public string Description { get; set; }

        [JsonProperty("unitPrice")]
        public double UnitPrice { get; set; }
    }
}
