@description('Asks the user to enter a name they want the Log Analytics Workspace to be called')
param logAnalyticsWorkspaceName string

@description('Sets the location/region for the resources from the resource group they are in.')
param location string = resourceGroup().location

@description('Asks the user to enter the length of time they want the logs to be retained for.')
@minValue(30)
@maxValue(730)
param retentionDays int

@description('Asks the user to enter the SKU for the Log Analytics Workspace.')
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
resource law 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
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
