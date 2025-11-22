# Shared Azure Health Workflows

Shared GitHub Actions workflows and utilities for the azure-health project family.

## Projects Using This Repository

- [py-azure-health](https://github.com/stuartshay/py-azure-health) - Python Azure Functions
- [pwsh-azure-health](https://github.com/stuartshay/pwsh-azure-health) - PowerShell Azure Functions
- [ts-azure-health](https://github.com/stuartshay/ts-azure-health) - TypeScript Next.js Frontend

## Reusable Workflows

### Destroy Infrastructure

Safely destroys resources for a specific project using tag-based filtering.

**Features:**
- Tag-based resource filtering (`project` tag)
- Preserves shared resource groups
- Protects resources from other projects
- Retry logic with exponential backoff
- Detailed reporting

**Usage Example:**

```yaml
name: Infrastructure Destroy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to destroy'
        required: true
        type: choice
        options:
          - dev
          - prod

jobs:
  destroy:
    uses: stuartshay/shared-azure-health/.github/workflows/destroy-infrastructure.yml@main
    with:
      project-name: py-azure-health
      environment: ${{ inputs.environment }}
      resource-group: rg-azure-health-${{ inputs.environment }}
    secrets:
      AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

## Utilities

### Retry Utils (`scripts/retry-utils.sh`)

Provides robust retry logic for Azure CLI operations with exponential backoff.

**Features:**
- Automatic retry on transient failures
- Exponential backoff
- Permanent failure detection
- Error type identification

**Usage:**

```bash
source scripts/retry-utils.sh

retry_azure_operation \
  5 \
  "Delete storage account" \
  az storage account delete --name myaccount --resource-group myrg --yes
```

## Tag Convention

All projects must tag their resources with:
```
project: <project-name>
```

Where `<project-name>` is one of:
- `py-azure-health`
- `pwsh-azure-health`
- `ts-azure-health`

## Resource Group Convention

- Development: `rg-azure-health-dev`
- Production: `rg-azure-health` or `rg-azure-health-prod`
- Shared: `rg-azure-health-shared`

## Authentication

All workflows use federated identity (OIDC) with a shared managed identity:
- Managed Identity: `id-github-actions-ts-azure-health`
- Resource Group: `rg-azure-health-shared`

## Contributing

When updating shared workflows:
1. Test changes in a development branch
2. Update version tags after merging
3. Update consuming projects to use new version
4. Document breaking changes

## Examples

See the `examples/` directory for complete workflow examples for each project.

## License

This is a shared infrastructure repository for the azure-health project family.
