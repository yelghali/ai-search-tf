# Day 1+: JSON-defined indexes

This independent Terraform root manages indexes on an existing Search service.
It never creates or manages the service. It calls the reusable
[search-index module](../modules/search-index/main.tf) once per `index_files` entry.

## Deploy the demos

Complete [Day 0](../entra-id/README.md) first. Use the same Azure identity and
subscription, then create a local `terraform.tfvars` in this directory:

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
