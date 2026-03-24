# Infrastructure/Detection as Code | CI/CD Pipelines
## Overview

This repository implements Infrastructure as Code (IaC) and Detection as Code (DaC) Pipelines that automatically deploy Azure resources and Sentinel analytics via GitHub Actions.

Rather than manually exporting and re-importing resources and analytic rules, these pipelines ensures rules are version controlled, consistently deployed, and easy to maintain over time.

## Repository Structure
### detection-as-code-CI-CD-pipeline/.github/workflows

YAML files used to push resources to Azure.

### detection-as-code-CI/CD-pipeline/detections

ARM templates of Sentinel analytics.

## How it works (Analytic deployment)

1. A detection rule is written or updated as an ARM template in the /detections folder.
2. The GitHub Actions workflow is manually triggered via workflow_dispatch (this can be changed to trigger when a push to the main branch is done).
3. The workflow authenticates to Azure and deploys the ARM template to the target Sentinel workspace.
4. The rule is live in Sentinel without any manual intervention.

## Goals

- Eliminate manual deployment of Sentinel detection rules.
- Ensure detection rules are version controlled and auditable.
- Standardise resource and rule deployment across environments using reusable templates.
- Reduce human error in resource and rule deployment.

## Tech Stack

- GitHub Actions (Pipeline orchestration)
- ARM Templates (Analytic rules)
- Microsoft Sentinel (Target deployment environment)
- Azure Resource Manager (Deployment engine)

## Issues I faced:

- Deploying an Analytic with a previously deleted Analytic's ID.

This was due to my exporting an Analytic from Sentinel and deleting it. I then tried to run the worflow with the ARM template writing the Analytic with the same ID the recently deleted one had, too soon after deleting it.

It probably would've worked if I had wait longer for Azure to forget about the previous ID, however, I changed the template to use ```guid(parameters('workspace'), 'test-rule')``` which uses the workspace name and a unique string ("test-rule") as inputs, which are hashed to produce a stable GUID.

This means the same workspace and string will always produce the same ID, preventing duplicate rules on redeployment.

## Notes

This repository is actively maintained and updated with new pipelines, improvements, and IaC/DaC projects over time.
