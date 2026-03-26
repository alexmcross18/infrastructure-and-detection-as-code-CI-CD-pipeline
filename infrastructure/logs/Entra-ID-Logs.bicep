//targetScope = 'tenant'

// Below is setting the Log Analytics Workspace's resourceId.
// param lawResourceId string = '/subscriptions/your-subscription-id/resourceGroups/your-resource-group-name/providers/Microsoft.OperationalInsights/workspaces/lawSentinel'

// Below is enabling all of the logs in diagnostic setting.
param enableSignInLogs bool = true
param enableAuditLogs bool = true
param enableNonInteractiveUserSignInLogs bool = true
param enableServicePrincipalSignInLogs bool = true
param enableManagedIdentitySignInLogs bool = true
param enableProvisioningLogs bool = true
param enableADFSSignInLogs bool = true
param enableRiskyUsersLogs bool = true
param enableUserRiskEvents bool = true
param enableRiskyServicePrincipalLogs bool = true
param enableServicePrincipalRiskEvents bool = true
param enableNetworkAccessTrafficLogs bool = true

// Below is the action of the above.
resource aadDiagnosticSettings 'microsoft.aadiam/diagnosticSettings@2017-04-01' = {
  name: 'aadDiagnosticSettings'
  properties: {
    workspaceId: lawResourceId
    logs: [
      {
        category: 'SignInLogs'
        enabled: enableSignInLogs
      }
      {
        category: 'AuditLogs'
        enabled: enableAuditLogs
      }
      {
        category: 'NonInteractiveUserSignInLogs'
        enabled: enableNonInteractiveUserSignInLogs
      }
      {
        category: 'ServicePrincipalSignInLogs'
        enabled: enableServicePrincipalSignInLogs
      }
      {
        category: 'ManagedIdentitySignInLogs'
        enabled: enableManagedIdentitySignInLogs
      }
      {
        category: 'ProvisioningLogs'
        enabled: enableProvisioningLogs
      }
      {
        category: 'ADFSSignInLogs'
        enabled: enableADFSSignInLogs
      }
      {
        category: 'RiskyUsers'
        enabled: enableRiskyUsersLogs
      }
      {
        category: 'UserRiskEvents'
        enabled: enableUserRiskEvents
      }
      {
        category: 'RiskyServicePrincipals'
        enabled: enableRiskyServicePrincipalLogs
      }
      {
        category: 'ServicePrincipalRiskEvents'
        enabled: enableServicePrincipalRiskEvents
      }
      {
        category: 'NetworkAccessTrafficLogs'
        enabled: enableNetworkAccessTrafficLogs
      }
    ]
  }
}
