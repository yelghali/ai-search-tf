terraform {
  required_version = ">= 1.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azapi" {}

variable "search_service_name" {
  type        = string
  description = "Existing Search service name from the Day 0 deployment."
}

variable "index_files" {
  type        = map(string)
  description = "Stable Terraform keys mapped to local JSON paths, relative to this directory or absolute."
  default = {
    hotels       = "definitions/hotels.index.json"
    reservations = "definitions/reservations.index.json"
  }
}

module "indexes" {
  source   = "../modules/index-creation"
  for_each = var.index_files

  search_service_name   = var.search_service_name
  index_definition_file = each.value
}

output "index_endpoints" {
  value = { for key, index in module.indexes : key => index.endpoint }
}
