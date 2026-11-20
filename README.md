# Azure AI Search: Day 0 infrastructure, Day 1+ indexes

Manage Azure AI Search with Terraform and Entra ID only. No index-creation
scripts or API keys. The same Terraform configuration works on Windows and Linux.

## Layout

- [Day 0: entra-id](ai-search-terraform/entra-id/README.md): service, resource
  group, and RBAC, in its own Terraform state.
- [Day 1+: indexes](ai-search-terraform/indexes/README.md): hotels and reservations
  demos loaded from local JSON files, in a separate Terraform state.
- [Reusable index module](ai-search-terraform/modules/search-index/main.tf):
  one native AzAPI data-plane resource per index.

## Prerequisites

Terraform 1.0+, Azure CLI authenticated with `az login`, and permissions to create
resources and assign roles (Owner, or Contributor plus User Access Administrator).
Use the same identity and subscription for both stages.

## Day 0

From `ai-search-terraform/entra-id`:

```shell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
terraform init
terraform plan -var="sku=free" -out=main.tfplan
terraform apply main.tfplan
terraform output -raw azurerm_search_service_name
```

Copy the service name output. Free allows one service per subscription.
The default SKU is Standard and is billable; keep passing `sku=free` or save it
in a local `terraform.tfvars`.

## Day 1, 2, 3...

From `ai-search-terraform/indexes`, create a local `terraform.tfvars`:

```hcl
search_service_name = "<SERVICE_NAME_FROM_DAY_0>"
```

Then:

```shell
terraform init
terraform plan -out=main.tfplan
terraform apply main.tfplan
```

This creates `hotels` and `reservations` from their local JSON definitions.
Later, edit the JSON or configure `index_files` to add indexes and rerun only
this stage. Day 1 does not manage or recreate the service.

**Removing an index entry deletes its index; changing its JSON name replaces it.**
Review plans, retain both states, and use separate backend keys in production.
Terraform state and local variable files must not be committed.

## Cleanup

Destroy indexes first from `ai-search-terraform/indexes`:

```shell
terraform destroy
```

Then destroy infrastructure from `ai-search-terraform/entra-id`:

```shell
terraform destroy -var="sku=free"
```

Destroying the service independently also deletes all its indexes and documents.
