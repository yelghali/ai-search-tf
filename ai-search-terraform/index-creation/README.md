# Day 1+: index creation from JSON

This independent Terraform root manages indexes on an existing Search service.
It never creates or manages the service. It calls the reusable
[index creation module](../modules/index-creation/main.tf) once per `index_files` entry.

## Deploy the demos

Complete [Day 0](../ai-search-creation/README.md) first. Authenticate with an
identity that has Search Service Contributor on that service; this can be a
different identity from Day 0. Create a local `terraform.tfvars` in this directory:

```hcl
search_service_name = "<DAY_0_SERVICE_NAME>"
```

Run on Windows or Linux:

```shell
terraform init
terraform plan -out=main.tfplan
terraform apply main.tfplan
terraform output index_endpoints
terraform plan -detailed-exitcode
```

The repeat plan should return 0 (no changes).
The defaults deploy:

- [hotels](definitions/hotels.index.json): multilingual descriptions and address.
- [reservations](definitions/reservations.index.json): hotel ID, guest name,
  dates, status, and amount. `HotelId` is a logical reference, not a server-side
  join or foreign-key constraint.

These are schema demos only; no documents are uploaded.

## Add or update indexes

Edit a JSON file and apply this stage again. To add or choose files, configure
the full map in local `terraform.tfvars`:

```hcl
search_service_name = "<DAY_0_SERVICE_NAME>"
index_files = {
  hotels       = "definitions/hotels.index.json"
  reservations = "definitions/reservations.index.json"
  custom       = "/absolute/path/to/custom.index.json"
}
```

Windows absolute paths can use escaped backslashes in HCL.
Paths are relative to the Terraform working directory or absolute. Files must
exist before planning and contain a Search API index definition with `name`
and `fields`. Index names must be unique within the service. The map keys are
stable Terraform identities; the JSON `name` determines the Azure index name.

No Bash/PowerShell selector, CLI index call, or embedded Terraform schema is
needed. AzAPI authenticates using Entra ID (Azure CLI locally or supported
`ARM_` settings in automation).

## Independent CI/CD pipeline

Run this root in its own pipeline with its own Entra service principal or managed
identity and remote state. The identity requires **Search Service Contributor**
at the target Search-service scope to create, read, update, and delete index
definitions. Search Index Data Contributor alone is not sufficient. It does not
need resource-group creation or role-assignment permissions.

Day 0 currently assigns the role only to its own identity. Provision the separate
index identity's assignment using the
[Day 0 Terraform example](../ai-search-creation/README.md#separate-cicd-identity-for-index-management)
or have an administrator grant it before this pipeline runs.

Configure the pipeline's supported AzAPI authentication, preferably workload
identity federation/OIDC. Typical inputs are `ARM_CLIENT_ID`, `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID`, and `ARM_USE_OIDC=true`, plus the CI platform's supported
OIDC token delivery. These settings alone do not configure federation: create
the federated credential and grant the job permission to request an ID token.
An Azure-authenticated service connection/CLI session is another option.
Do not pass a Search key.

Pass `search_service_name` from the Day 0 output as a pipeline variable (for
example, `TF_VAR_search_service_name`). No infrastructure-state access is needed.
The pipeline must have access to its own backend for state reads, writes, and
locking; Search RBAC does not provide storage access. Use an isolated backend
key and storage permissions appropriate to your backend.

The runner must also reach the Search data-plane endpoint. A service with private
network access needs a runner with the required network connectivity and DNS.
Wait for initial RBAC propagation before planning/applying. Later index changes
do not require running Day 0 again.

## Lifecycle and access

- Removing a map entry deletes that index and its documents on apply.
- Changing a JSON name replaces the index. Unsupported field-type changes fail;
  plan an explicit data migration rather than assuming a schema rebuild is safe.
- Separate state prevents index changes from altering Day 0 infrastructure.
  Never point an existing state at another service without reviewing replacement.
- Keep both states and use distinct remote-backend keys in production.
- Role propagation may cause 401/403 just after Day 0; wait and retry. The Day 1
  identity requires Search Service Contributor on the target service.
- Querying/uploading documents requires separate Search Index Data roles.

To adopt an existing index, quote the full module address appropriately for your
shell and import using the ID
`SERVICE.search.windows.net/indexes('NAME')|Microsoft.Search/searchServices/indexes@2024-07-01`.
Do not leave the same index managed by another Terraform state.

## Cleanup

```shell
terraform destroy
```

This deletes only this state's indexes. Destroy Day 0 afterward if desired.
