# Day 0: AI Search creation

Creates only a resource group, Azure AI Search service (key authentication
disabled), and service-scoped Search Service Contributor assignment for the
deploying identity. Indexes are managed separately in [Day 1+](../index-creation/README.md).

## Deploy

Requires Terraform 1.0+, Azure CLI login, and permissions to create resources
and assign roles. Run from this directory on Windows or Linux:

```shell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
terraform init
terraform plan -var="sku=free" -out=main.tfplan
terraform apply main.tfplan
terraform output
```

Pass `azurerm_search_service_name` to the indexes stage. Other outputs are
`resource_group_name` and `search_service_endpoint`.
No index schema or index file input belongs in this stage.

## Separate CI/CD identity for index management

Yes: run this root in an infrastructure pipeline and the
[index-creation root](../index-creation/README.md) in a different pipeline with a
different Entra identity. This root's existing RBAC resource assigns Search
Service Contributor only to the identity authenticated to AzureRM.

For a separate index pipeline, add an assignment to this Day 0 configuration
(or manage it in your organization's RBAC configuration). For example:

```hcl
variable "index_pipeline_principal_id" {
  type        = string
  description = "Entra object ID of the index pipeline service principal or managed identity, not its client/application ID."
}

resource "azurerm_role_assignment" "index_pipeline" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = var.index_pipeline_principal_id
  principal_type       = "ServicePrincipal"
}
```

This is an optional example, not a built-in input in the shipped configuration.
Service principals and managed identities use `ServicePrincipal`; use the
appropriate principal type if assigning to a user or group instead.
The identity must exist in the service's tenant.

The Day 0 pipeline needs resource-creation permissions plus permission to assign
this role at the service scope (for example, Contributor plus User Access
Administrator, subject to any role-assignment conditions).
The index pipeline needs only Search Service Contributor for index definitions,
not Owner or role-assignment permissions.

Use separate federated credentials/service connections per pipeline. Configure
AzureRM authentication with that pipeline's identity, for example supported
OIDC `ARM_` settings and CI-specific token delivery; never reuse an interactive
developer login in unattended CI. Pass only the service name output to Day 1.
Protect infrastructure state separately: it can contain service keys even though
key authentication is disabled. Index CI does not need access to it.

Configure remote backends with separate keys and state-storage permissions.
Backend permissions are independent of Azure resource permissions; this sample
does not provision or configure a backend. Do not copy local state into Git.

## Configuration and lifecycle

- Default location: eastus. Override `resource_group_location`.
- Default SKU: Standard (billable). Free supports one service per subscription.
  Retain `sku=free` on subsequent commands or save it in local `terraform.tfvars`.
- Replica and partition counts remain configurable.
- A repeat same-variable plan should report no changes.
- Keep state secure: AzureRM can store service keys in state even though key
  authentication is disabled. Neither stage uses those keys.
- RBAC can take time to propagate. If Day 1 returns 401/403, wait and retry.
- The identity must already have role-assignment permission; Terraform cannot
  bootstrap that permission. No prerequisite RBAC script is needed.
- A different Day 1 identity needs its own Search Service Contributor assignment.
  Document readers/writers additionally need the appropriate Search Index Data role.

## Cleanup

Destroy [Day 1 indexes](../index-creation/README.md) first, then:

```shell
terraform destroy -var="sku=free"
```

This deletes the service and all remaining indexes/documents.

## Upgrading from the former combined configuration

Do not apply this refactor blindly to an existing combined state: resources
removed from a configuration are planned for deletion. Back up state and migrate
existing index resources into the indexes stage (remove only their old state
addresses and import into the module addresses) before applying, or deliberately
destroy and recreate the demo deployment. The test deployment was recreated.
