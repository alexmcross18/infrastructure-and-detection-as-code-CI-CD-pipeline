using '../Log-Analytics-Workspace.bicep'

param logAnalyticsWorkspaceName = '-law-sentinel-client-a'
param retentionDays = 90
param SKU = 'PerGB2018'
