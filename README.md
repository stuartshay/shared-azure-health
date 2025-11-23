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
- Progress messages sent to stderr (doesn't pollute stdout)

**Usage:**

```bash
source scripts/retry-utils.sh

retry_azure_operation \
  5 \
  "Delete storage account" \
  az storage account delete --name myaccount --resource-group myrg --yes
```

### Key Vault Utils (`scripts/keyvault-utils.sh`)

Utilities for managing Azure Key Vault secrets with validation.

**Features:**
- Set and retrieve Key Vault secrets
- Verify secret values
- Update and verify in one operation
- URL accessibility testing

**Functions:**
- `set_keyvault_secret <vault-name> <secret-name> <secret-value>`
- `get_keyvault_secret <vault-name> <secret-name>`
- `verify_keyvault_secret <vault-name> <secret-name> <expected-value>`
- `test_url_accessible <url>`
- `update_and_verify_keyvault_secret <vault-name> <secret-name> <secret-value>`

**Usage:**

```bash
source scripts/keyvault-utils.sh

# Update and verify a secret
update_and_verify_keyvault_secret \
  "my-keyvault" \
  "function-app-url" \
  "https://my-function-app.azurewebsites.net"

# Test if a URL is accessible
if test_url_accessible "https://my-function-app.azurewebsites.net"; then
  echo "✅ URL is accessible"
fi
```

### Deployment Verification Utils (`scripts/deployment-verification.sh`)

Utilities for verifying Azure Function App deployments and infrastructure health.

**Features:**
- Check Function App running state
- Test Function App health endpoints
- Verify storage account connectivity
- Verify Application Insights configuration
- Complete deployment verification workflow

**Functions:**
- `check_function_app_running <function-app-name> <resource-group>`
- `test_function_app_health <function-app-url>`
- `verify_storage_account <storage-account-name> <resource-group>`
- `verify_app_insights <app-insights-name> <resource-group>`
- `verify_deployment <function-app-name> <storage-account-name> <app-insights-name> <resource-group> <function-url>`

**Usage:**

```bash
source scripts/deployment-verification.sh

# Check if Function App is running
if check_function_app_running "my-function-app" "my-rg"; then
  echo "✅ Function App is running"
fi

# Run complete deployment verification
verify_deployment \
  "my-function-app" \
  "mystorageaccount" \
  "my-app-insights" \
  "my-rg" \
  "https://my-function-app.azurewebsites.net"
```

### Policy Query Utils (`scripts/policy-query.sh`)

Utilities for querying Azure Policy assignments, exemptions, and compliance states.

**Features:**
- Query policy assignments with compliance states
- Get policy descriptions from definitions
- Find non-compliant resources
- Query policy exemptions
- Format policy data for Markdown display
- Generate complete policy status reports

**Functions:**
- `get_policy_assignments_with_compliance <resource-group-name>`
- `get_policy_description <policy-definition-id>`
- `get_noncompliant_resources <resource-group-name> <policy-assignment-name>`
- `get_policy_assignments <resource-group-name>` (legacy)
- `get_policy_exemptions <resource-group-name>`
- `format_policy_assignments <json-array> <resource-group-name>`
- `format_policy_exemptions <json-array>`
- `generate_policy_report <resource-group-name>`

**Usage:**

```bash
source scripts/policy-query.sh

# Generate a complete policy status report
generate_policy_report "my-resource-group"

# Query specific policy assignments with compliance
assignments=$(get_policy_assignments_with_compliance "my-resource-group")
format_policy_assignments "$assignments" "my-resource-group"

# Get policy exemptions
exemptions=$(get_policy_exemptions "my-resource-group")
format_policy_exemptions "$exemptions"

# Find non-compliant resources
noncompliant=$(get_noncompliant_resources "my-resource-group" "policy-assignment-name")
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
