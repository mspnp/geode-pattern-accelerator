using System;
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

        [JsonProperty("category")]
        public string Category { get; set; }

        [JsonProperty("warehouses")]
        public WarehouseAvailability[] Warehouses { get; set; }
    }

    public class WarehouseAvailability
    {
        [JsonProperty("warehouseId")]
        public Guid WarehouseId { get; set; }

        [JsonProperty("unitsAvailable")]
        public int UnitsAvailable { get; set; }
    }
}
