@description('Name of the Log Analytics Workspace.')
param logAnalyticsWorkspaceName string

@description('Location/region inherited from the resource group.')
param location string = resourceGroup().location

@description('Number of days to retain logs. Between 30 and 730.')
@minValue(30)
@maxValue(730)
param retentionDays int

@description('SKU for the Log Analytics Workspace.')
@allowed([
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
  'CapacityReservation'
  'LACluster'
  'Unlimited'
  'Free'
])
param SKU string

// Below is creating a Log Analytics Workspace.
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName                                       // Name of the Log Analytics Workspace.
  location: location                                  // Location/Region of the Log Analytics Workspace.
  sku: {
    name: SKU                                         // SKU of the Log Analytics Workspace.
  }
  properties: {
    retentionInDays: retentionDays                    // Number of days to retain logs in the Log Analytics Workspace.
  }
}

// Below is creating a Sentinel instance.
resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${law.name})'               // Name of the Sentinel instance.
  location: location                                  // Location/Region of the Sentinel instance.
  properties: {
    workspaceResourceId: law.id                       // ID of the Log Analytics Workspace it will pull logs from.
  }
  plan: {
    name: 'SecurityInsights(${law.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
}

// Below is linking Sentinel to the Log Analytics Workspace.
resource sentinelOnboarding 'Microsoft.SecurityInsights/onboardingStates@2024-03-01' = {
  name: 'default'
  scope: law
  properties: {}
  dependsOn: [
    sentinel
  ]
}

// Writes the output of what was created to the user.
output workspaceId string = law.id
output workspaceName string = law.name
output sentinelName string = sentinel.name
