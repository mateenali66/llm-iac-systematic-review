@description('Specifies the globally unique name for the Cosmos DB account.')
param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'

@description('Specifies the array of locations for the Cosmos DB account. The first location in the array will be the primary write region.')
param locations array = [
  {
    locationName: resourceGroup().location