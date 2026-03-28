param watchlistAlias string = 'knownLocations'
param csvContent string = ''
param workspaceName string

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-02-01' existing = {
  name: workspaceName
}

resource knownLocations 'Microsoft.SecurityInsights/watchlists@2023-09-01-preview' = {
  name: watchlistAlias
  scope: workspace
  properties: {
    displayName: 'Known Locations'
    itemsSearchKey: 'CountryCode'
    provider: 'Microsoft'
    source: 'Local file'
    rawContent: csvContent
    contentType: 'text/csv'
  }
}
