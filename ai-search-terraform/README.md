# Terraform stages

- [entra-id](entra-id/README.md): Day 0 Search infrastructure and RBAC.
- [indexes](indexes/README.md): Day 1+ JSON-defined indexes, separate state.
- [modules/search-index](modules/search-index/main.tf): reusable native AzAPI
  index module used by the indexes stage.

See the [quick start](../README.md). Run Terraform from a stage directory, not
this directory. Both stages use Entra ID and run on Windows and Linux without
helper scripts.
