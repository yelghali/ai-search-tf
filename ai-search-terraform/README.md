# Terraform stages

- [ai-search-creation](ai-search-creation/README.md): Day 0 Search infrastructure and RBAC.
- [index-creation](index-creation/README.md): Day 1+ JSON-defined indexes, separate state.
- [modules/index-creation](modules/index-creation/main.tf): reusable native AzAPI
  index module used by the indexes stage.

See the [quick start](../README.md). Run Terraform from a stage directory, not
this directory. Both stages use Entra ID and run on Windows and Linux without
helper scripts.
