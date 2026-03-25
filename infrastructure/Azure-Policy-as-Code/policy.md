```
{
    // -------------------------------------------------------------------------
    // ARM TEMPLATE — Policy Definition: Deny Public Blob Access
    //
    // This is the full ARM template format of the policy definition.
    // This single file contains everything needed to deploy the policy — making it suitable for automated pipelines.
    //
    // No manual arguments needed beyond what is stored in GitHub secrets/vars.
    // -------------------------------------------------------------------------
 
    // Every ARM template must declare the schema it conforms to.
    // This tells Azure which API to validate the template against.
    // For subscription-scoped deployments (which policy definitions require).
    // use the subscriptionDeploymentTemplate schema.

    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
 
    // Required by ARM.
    "contentVersion": "1.0.0.0",
 
    // -----------------------------------------------------------------------
    // PARAMETERS
    // These are the ARM template parameters — not to be confused with the
    // policy parameters inside the definition itself (those come later).
    //
    // ARM parameters are what YOU pass in at deployment time.
    // Keeping the policy name and effect here means:
    //   - The same template deploys to any environment.
    //   - Effect can be "Audit" in dev and "Deny" in prod without editing the file for example.
    //   - The policy name can be overridden if needed without touching the logic
    // -----------------------------------------------------------------------
    "parameters": {
 
        // The name used to identify this policy definition in Azure.
        "policyName": {
            "type": "string",
            "defaultValue": "deny-storage-public-blob-access",
            "metadata": {
                "description": "The name of the policy definition resource in Azure."
            }
        },
 
        // Controls the effect when the policy is assigned.
        // Default is Audit so deployment to an existing environment is safe —
        // it will report non-compliant resources without blocking anything.
        "policyEffect": {
            "type": "string",
            "defaultValue": "Audit",
            "allowedValues": [
                "Audit",
                "Deny",
                "Disabled"
            ],
            "metadata": {
                "description": "The effect applied to non-compliant resources. Audit flags, Deny blocks, Disabled turns the policy off."
            }
        }
    },
 
    // -----------------------------------------------------------------------
    // RESOURCES
    // The array of Azure resources this template will create or update.
    // In this case, a single policy definition at subscription scope.
    // -----------------------------------------------------------------------
    "resources": [
        {
            // The ARM resource type for a policy definition.
            "type": "Microsoft.Authorization/policyDefinitions",
 
            // API version to use when deploying this resource.
            "apiVersion": "2021-06-01",
 
            // References the policyName ARM parameter defined above.
            // This is ARM template syntax — different from policy parameter.
            // syntax ([parameters('effect')]) used inside the policy rule.
            "name": "[parameters('policyName')]",
 
            "properties": {
 
                "displayName": "Deny public blob access on storage accounts",
                "policyType": "Custom",
                "mode": "All",
                "description": "Denies the creation or update of storage accounts where allowBlobPublicAccess is enabled or not explicitly set to false. Public blob access allows unauthenticated read access to container contents and is a common cause of data exposure incidents.",

                // Selects the "Storage" category or creates one if one doesn't exist.
                "metadata": {
                    "category": "Storage",
                    "version": "1.0.0"
                },
 
                // -----------------------------------------------------------
                // POLICY PARAMETERS
                // These live inside properties and are separate from the ARM
                // parameters above. These are the parameters exposed when
                // someone assigns this policy — letting them choose the effect
                // per assignment without editing the definition itself.
                //
                // The defaultValue here references the ARM parameter above,
                // so whatever effect was chosen at deployment time becomes
                // the default when the policy is assigned.
                // -----------------------------------------------------------
                "parameters": {
                    "effect": {
                        "type": "String",
                        "metadata": {
                            "displayName": "Effect",
                            "description": "Audit logs a warning but allows the deployment. Deny blocks it outright. Disabled turns the policy off."
                        },
                        "allowedValues": [
                            "Audit",
                            "Deny",
                            "Disabled"
                        ],
                        "defaultValue": "[parameters('policyEffect')]"
                    }
                },
 
                // -----------------------------------------------------------
                // POLICY RULE
                // The logic is the same regardless of how the definition is deployed.
                // -----------------------------------------------------------
                "policyRule": {
                    "if": {
                        "allOf": [
                            {
                                // Only evaluate storage account resources.
                                "field": "type",
                                "equals": "Microsoft.Storage/storageAccounts"
                            },
                            {
                                // Fire if public access is explicitly true OR
                                // the property is missing entirely (unsafe default).
                                "anyOf": [
                                    {
                                        "field": "Microsoft.Storage/storageAccounts/allowBlobPublicAccess",
                                        "equals": "true"
                                    },
                                    {
                                        "field": "Microsoft.Storage/storageAccounts/allowBlobPublicAccess",
                                        "exists": "false"
                                    }
                                ]
                            }
                        ]
                    },
                    "then": {
                        // References the policy parameter (not the ARM parameter).
                        // This is what makes the effect configurable per assignment.
                        "effect": "[parameters('effect')]"
                    }
                }
            }
        }
    ],
 
    // -----------------------------------------------------------------------
    // OUTPUTS
    // Written to the deployment log after a successful run.
    // Useful for downstream pipeline steps or just confirming what was created.
    // Matches the output pattern from your existing Bicep templates.
    // -----------------------------------------------------------------------
    "outputs": {
        "policyDefinitionId": {
            "type": "string",
            // resourceId() constructs the full Azure resource ID from the type
            // and name. You'll need this ID when referencing this definition
            // inside an initiative or assignment template.
            "value": "[resourceId('Microsoft.Authorization/policyDefinitions', parameters('policyName'))]"
        },
        "policyName": {
            "type": "string",
            "value": "[parameters('policyName')]"
        }
    }
}
```
