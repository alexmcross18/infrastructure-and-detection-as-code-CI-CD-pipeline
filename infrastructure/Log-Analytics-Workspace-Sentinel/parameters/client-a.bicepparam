using '../Log-Analytics-Workspace.bicep'

param logAnalyticsWorkspaceName = 'sentinel-law-client-a'
param retentionDays = 90
param SKU = 'PerGB2018'
