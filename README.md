# Azure AI Search with Terraform and Entra ID

Automatically deploy an Azure resource group, an Azure AI Search service, and a
sample `hotels` index in one Terraform apply. Authentication uses Microsoft Entra
ID only; API-key authentication is disabled.

## How it works

1. Terraform provisions the resource group and search service.
2. Terraform grants **Search Service Contributor** to the deploying identity at
   the search-service scope.
3. A small PowerShell script obtains an Azure CLI bearer token and creates or
   updates the index using the Search REST API, retrying readiness failures.

Infrastructure, RBAC, and the index schema are defined in Terraform. No admin
key, manual index creation, or prerequisite RBAC script is needed.

## Prerequisites

- Terraform 1.0+, Azure CLI, and PowerShell 7+ (`pwsh` on PATH).
- An Azure login with permission to create resources and assign roles:
  **Owner**, or **Contributor** plus **User Access Administrator**, at the
  deployment scope.
- Terraform and Azure CLI must use the same identity.

## Quick start (PowerShell)

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
cd ai-search-terraform\entra-id
terraform init
terraform plan -var="sku=free" -out=main.tfplan
terraform apply main.tfplan
```

The Free tier allows one service per subscription. The template default is
**Standard**, which is billable. Continue passing `-var="sku=free"` on subsequent
plans/applies, or save `sku = "free"` in a local, git-ignored `terraform.tfvars`.
Terraform state must be retained to manage the deployed resources.

See the [Entra ID deployment guide](ai-search-terraform/entra-id/README.md) for
verification, configuration, troubleshooting, and cleanup.
