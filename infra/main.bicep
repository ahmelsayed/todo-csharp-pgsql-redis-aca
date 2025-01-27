targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string
param acaLocation string = 'northcentralusstage'
param resourceGroupName string = ''

param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''

param postgreSqlName string = 'postgres'
param redisCacheName string = 'redis'
param apiContainerAppName string = 'api-service'
param apiImageName string = ''
param webContainerAppName string = 'web-service'
param webImageName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module containerApps './core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    name: 'app'
    acaLocation: acaLocation
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    tags: tags
  }
}

module postgreSql './core/host/springboard-container-app.bicep' = {
  name: 'postgres'
  scope: rg
  params: {
    name: postgreSqlName
    location: acaLocation
    tags: tags
    environmentId: containerApps.outputs.environmentId
    serviceType: 'postgres'
    minReplicas: 1
  }
}

module redis './core/host/springboard-container-app.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    name: redisCacheName
    location: acaLocation
    tags: tags
    environmentId: containerApps.outputs.environmentId
    serviceType: 'redis'
    minReplicas: 1
  }
}

module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: apiContainerAppName
    location: acaLocation
    tags: tags
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    imageName: apiImageName
    containerRegistryName: containerApps.outputs.registryName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    redisServiceName: redis.outputs.serviceName
    postgresServiceName: postgreSql.outputs.serviceName
    minReplicas: 1
  }
}

// the application frontend
module web './app/web.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: webContainerAppName
    location: acaLocation
    tags: tags
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    imageName: webImageName
    containerRegistryName: containerApps.outputs.registryName
    apiBaseUrl: 'https://${apiContainerAppName}.${containerApps.outputs.defaultDomain}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    minReplicas: 1
  }
}

module shell 'shell.bicep' = {
  name: 'shell'
  scope: rg
  params: {
    location: acaLocation
    environmentName: containerApps.outputs.environmentName
  }
}

// App outputs
output SERVICE_API_IMAGE_NAME string = api.outputs.SERVICE_API_IMAGE_NAME
output SERVICE_WEB_IMAGE_NAME string = web.outputs.SERVICE_WEB_IMAGE_NAME
output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output SERVICE_WEB_NAME string = web.outputs.SERVICE_WEB_NAME
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApps.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
output AZURE_LOCATION string = location
output AZURE_LOG_ANALYTICS_NAME string = monitoring.outputs.logAnalyticsWorkspaceName
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_ENDPOINTS array = [ api.outputs.SERVICE_API_URI ]
output REACT_APP_API_BASE_URL string = api.outputs.SERVICE_API_URI
output REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output REACT_APP_WEB_BASE_URL string = web.outputs.SERVICE_WEB_URI
output AZURE_REDIS_SERVICE_NAME string = redis.outputs.serviceName
output AZURE_POSTGRES_SERVICE_NAME string = postgreSql.outputs.serviceName
