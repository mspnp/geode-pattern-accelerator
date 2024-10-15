# required variables
base_name="abcdef" 
primary_location="eastus" 
additional_locations=["centralus", "westus"]

# optional variables
database_max_throughput="10000"
container_max_throughput="4000"
consistency_level="Session" 
availability_zones="false"
multi_region_write="false"
app_service_sku="Y1"
front_door_sku="Standard_AzureFrontDoor"