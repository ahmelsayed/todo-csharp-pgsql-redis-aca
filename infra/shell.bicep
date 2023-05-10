param location string
param environmentName string

resource shell 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'shell'
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8376
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'main'
          image: 'docker.io/ahmelsayed/p1:1'
          env: [
            {
              name: 'ALLOWED_HOSTNAMES'
              value: 'shell.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'TERM'
              value: 'xterm'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/test/storage'
              volumeName: 'azurefilesmount'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'azurefilesmount'
          storageName: 'azurefilesstorage'
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: environmentName
}
