param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceName string

var fileShareName = 'share-1'
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: uniqueString(resourceGroup().name)
  location: 'centralus'
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  resource fileService 'fileServices@2022-09-01' = {
    name: 'default'
    resource fileShare 'shares@2022-09-01' = {
      name: fileShareName
      properties: {
        enabledProtocols: 'SMB'
        accessTier: 'Premium'
      }
    }
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
  resource azureFilesStorage 'storages@2022-11-01-preview' = {
    name: 'azurefilesstorage2'
    properties: {
      azureFile: {
        accountName: storageAccount.name
        shareName: storageAccount::fileService::fileShare.name
        accessMode: 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
      }
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

output name string = containerAppsEnvironment.name
output id string = containerAppsEnvironment.id
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
