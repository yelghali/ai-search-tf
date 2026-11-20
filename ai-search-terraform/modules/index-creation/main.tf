terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

variable "search_service_name" {
  type        = string
  description = "Existing Azure AI Search service name."
}

variable "index_definition_file" {
  type        = string
  description = "Local JSON file containing the index name and fields."
  validation {
    condition     = can(jsondecode(file(var.index_definition_file)).name) && can(jsondecode(file(var.index_definition_file)).fields)
    error_message = "Provide a readable JSON index definition containing name and fields."
  }
}

variable "api_version" {
  type    = string
  default = "2024-07-01"
}

locals {
  definition = jsondecode(file(var.index_definition_file))
}

resource "azapi_data_plane_resource" "index" {
  type      = "Microsoft.Search/searchServices/indexes@${var.api_version}"
  parent_id = "${var.search_service_name}.search.windows.net"
  name      = local.definition.name
  body      = local.definition
}

output "name" {
  value = azapi_data_plane_resource.index.name
}

output "endpoint" {
  value = "https://${azapi_data_plane_resource.index.parent_id}/indexes/${azapi_data_plane_resource.index.name}?api-version=${var.api_version}"
}
