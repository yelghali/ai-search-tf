# Azure AI Search Terraform sample (Entra ID)

This configuration deploys an Azure Resource Group, an Azure AI Search service,
and a sample `hotels` index using Microsoft Entra ID only. Key authentication is
disabled. Azure CLI acquires a bearer token for the Search data plane.

## Prerequisites
- Terraform 1.0+
- Azure CLI installed and authenticated (`az login` or `az login --service-principal ...`)
- Permissions in the target subscription to create resources and assign the **Search Service Contributor** role on the Search service
- PowerShell 7+ (`pwsh` on PATH), used by Terraform on Windows, Linux, and macOS
- `curl` installed (optional; for verification samples)
- `jq` installed (optional; for verification samples)

Terraform uses your current Azure CLI credentials by default. If you run Terraform with a service principal via `ARM_` environment variables, ensure the Azure CLI is also logged in as the same principal so it can request an access token during index creation.

## Files (root)
- `main.tf` – resource group and search service
- `providers.tf` – Terraform and provider requirements (azurerm, random, null)
- `variables.tf` – configurable variables with validations
- `outputs.tf` – key outputs after deployment
- `index.tf` – grants RBAC and creates the sample hotels index via Entra ID-authenticated REST calls
- `create-index.ps1` – creates or updates the index, retrying transient service and RBAC propagation failures for up to ten minutes

## Deployment steps
1. Change to this directory:

   ```bash
   cd ai-search-terraform/entra-id
   ```

2. Initialize Terraform and download providers:

   ```bash
   terraform init -upgrade
   ```

3. Create an execution plan:

   ```bash
   terraform plan -out main.tfplan
   ```

4. Apply the plan to deploy the infrastructure and create the hotels index:

   ```bash
   terraform apply main.tfplan
   ```

   During the apply Terraform disables API-key authentication (Entra ID only), assigns the **Search Service Contributor** role to the current identity, and calls the Search REST API with an access token from `az account get-access-token`. This role manages index definitions; **Search Index Data Contributor** only manages documents and cannot create indexes. If propagation exceeds the retry window, run `terraform apply` again once the role assignment is effective.

   RBAC is managed entirely by Terraform; no prerequisite RBAC script is needed. The deploying identity must already have permission to create role assignments (for example, Owner or User Access Administrator in addition to Contributor). If it does not, an administrator must grant that permission before deployment.

   For a no-charge test, pass `-var "sku=free"` to `terraform plan`. Only one Free search service is allowed per subscription. Standard (the default) is billable.

   Index definition changes trigger a new PUT on apply. Some schema changes require rebuilding an index and will fail explicitly instead of deleting existing data. Terraform destroy removes the service and its indexes; the provisioner does not manage independent index deletion or detect out-of-band index changes.

## Verify
### PowerShell

Run from this directory after applying:

```powershell
$resourceGroup = terraform output -raw resource_group_name
$searchService = terraform output -raw azurerm_search_service_name
$endpoint = terraform output -raw index_create_endpoint

az search service show --name $searchService --resource-group $resourceGroup `
    --query "{name:name,sku:sku.name,keysDisabled:disableLocalAuth}"

$token = az account get-access-token --resource https://search.azure.com `
    --query accessToken -o tsv
if ($LASTEXITCODE -ne 0) { throw "Unable to obtain a Search token." }
$index = Invoke-RestMethod -Uri $endpoint -Headers @{ Authorization = "Bearer $token" }
$index | ConvertTo-Json -Depth 10

terraform plan -var="sku=free" -detailed-exitcode
```

Expect `keysDisabled: true`, an index named `hotels` (unless overridden), and
five top-level fields including the complex `Address` field. After a successful
apply, the same-variable plan should report no changes (exit code 0).
Use your actual SKU if it is not Free.

### Bash

- Show the created Search service:

  ```bash
  resource_group_name=$(terraform output -raw resource_group_name)
  search_service_name=$(terraform output -raw azurerm_search_service_name)

  az search service show \
    --name "$search_service_name" \
    --resource-group "$resource_group_name"
  ```

- Get the hotels index definition with Entra ID authentication:

  ```bash
  access_token=$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)
  curl -sSf \
    -H "Authorization: Bearer $access_token" \
    "https://$search_service_name.search.windows.net/indexes/hotels?api-version=2024-07-01" \
    | jq .
  ```

## Clean up
Destroy all created resources when finished:

```bash
terraform destroy -var="sku=free"
```

## Notes
- Default region is `eastus`; override with `-var "resource_group_location=<region>"`.
- Default SKU is `standard`; valid values: `free`, `basic`, `standard`, `standard2`, `standard3`, `storage_optimized_l1`, `storage_optimized_l2`.
- On Windows PowerShell, use `cd ai-search-terraform\entra-id`. Terraform deployment commands are the same; verification snippets above use Bash.
- The sample index uses the 2024-07-01 API by default; adjust with `-var "api_version=..."` if needed.
- Keep the same variable values for subsequent plans/applies. For a Free
  deployment, save `sku = "free"` in a git-ignored `terraform.tfvars` or continue
  passing `-var="sku=free"`; otherwise the Standard default can propose a tier change.
- Keep Terraform state secure and out of source control. The AzureRM provider
  can store service keys in state even when key authentication is disabled;
  this configuration never uses them for index creation.

## Troubleshooting

- **Role assignment denied:** an administrator must grant the deploying identity
  role-assignment permission at the deployment scope before Terraform runs.
  Terraform cannot bootstrap permissions it does not already have.
- **HTTP 401/403:** ensure Azure CLI and Terraform use the same identity and
  subscription. The script retries propagation failures; if the retry window
  expires, check permissions and rerun apply.
- **Free service quota exceeded:** use another subscription or explicitly choose
  a paid SKU. Do not delete an unrelated existing service to make room.
- **`pwsh` not found:** install PowerShell 7 and ensure it is on PATH.
- **Index schema rejected:** inspect the REST error. Existing field types cannot
  always be changed in place; use a new index name or plan a deliberate rebuild.

Search Service Contributor manages index definitions but does not grant document
query/upload access. If an application needs those operations, separately assign
Search Index Data Reader or Search Index Data Contributor as appropriate.
