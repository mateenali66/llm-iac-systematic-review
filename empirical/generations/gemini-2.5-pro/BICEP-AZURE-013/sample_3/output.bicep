@description('The globally unique name of the Cosmos DB account.')
@minLength(3)
@maxLength(44)
param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'

@description('The primary location for the Cosmos DB account. This will be the write region.')
param primaryRegion string = resourceGroup().location

@description('The secondary location for the Cosmos DB account. This will be a read region.')
param secondaryRegion string

@description('The consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param consistencyLevel string = 'Session'

@description('When the consistency level is Bounded Staleness, this is the number of stale requests tolerated.')
param maxStalenessPrefix int