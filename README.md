# Azure AI Search: Day 0 infrastructure, Day 1+ indexes

Manage Azure AI Search with Terraform and Entra ID only. No index-creation
scripts or API keys. The same Terraform configuration works on Windows and Linux.

## Layout

- [Day 0: AI Search creation](ai-search-terraform/ai-search-creation/README.md): service, resource
  group, and RBAC, in its own Terraform state.
- [Day 1+: index creation](ai-search-terraform/index-creation/README.md): hotels and reservations
  demos loaded from local JSON files, in a separate Terraform state.
- [Reusable index creation module](ai-search-terraform/modules/index-creation/main.tf):
  one native AzAPI data-plane resource per index.

## Prerequisites

Terraform 1.0+, Azure CLI authenticated with `az login`, and permissions to create
resources and assign roles (Owner, or Contributor plus User Access Administrator).
The stages can use different CI/CD pipelines and Entra identities. Each identity
must have the permissions for its stage on the target resources.

## Separate CI/CD pipelines and identities

| Pipeline | Identity permissions | Terraform state |
| --- | --- | --- |
| Day 0: service creation | Resource creation and role-assignment permissions at the deployment scope | Infrastructure state only |
| Day 1+: index creation | Search Service Contributor on the existing Search service | Index state only |

The current Day 0 configuration grants Search Service Contributor to **its own
deploying identity**, not automatically to a separate index-pipeline identity.
Before the index pipeline runs, Day 0 or an administrator must grant that second
identity the role. See the [Terraform RBAC example](ai-search-terraform/ai-search-creation/README.md#separate-cicd-identity-for-index-management).

Use separate workload identity federation/OIDC credentials or service connections
for each pipeline. Pass the Day 0 service-name output to Day 1 as a pipeline
variable; Day 1 does not need access to the infrastructure state.
Configure distinct remote-backend keys (and appropriate storage access controls)
for the two roots. Backend authentication/permissions are separate from Search
permissions; no backend is configured by this sample.

Run Day 0 first and allow RBAC propagation before Day 1. Subsequent JSON-only
changes run only Day 1. For teardown, run Day 1 destroy before Day 0 destroy.

## Day 0

From `ai-search-terraform/ai-search-creation`:

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

From `ai-search-terraform/index-creation`, create a local `terraform.tfvars`:

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

Destroy indexes first from `ai-search-terraform/index-creation`:

```shell
terraform destroy
```

Then destroy infrastructure from `ai-search-terraform/ai-search-creation`:

```shell
terraform destroy -var="sku=free"
```

Destroying the service independently also deletes all its indexes and documents.
