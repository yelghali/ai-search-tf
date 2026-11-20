data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "search_service_contributor" {
  name  = "Search Service Contributor"
  scope = azurerm_resource_group.rg.id
}

resource "azurerm_role_assignment" "search_service_contributor" {
  scope              = azurerm_search_service.search.id
  role_definition_id = data.azurerm_role_definition.search_service_contributor.role_definition_id
  principal_id       = data.azurerm_client_config.current.object_id
}

locals {
  search_service_name = azurerm_search_service.search.name
  search_endpoint     = "https://${local.search_service_name}.search.windows.net"
  hotels_index_definition = jsonencode({
    name = var.index_name,
    fields = [
      { name = "HotelId", type = "Edm.String", key = true, retrievable = true, searchable = true, filterable = true },
      { name = "HotelName", type = "Edm.String", retrievable = true, searchable = true, filterable = false, sortable = true, facetable = false },
      { name = "Description", type = "Edm.String", retrievable = true, searchable = true, filterable = false, sortable = false, facetable = false, analyzer = "en.microsoft" },
      { name = "Description_fr", type = "Edm.String", retrievable = true, searchable = true, filterable = false, sortable = false, facetable = false, analyzer = "fr.microsoft" },
      {
        name = "Address",
        type = "Edm.ComplexType",
        fields = [
          { name = "StreetAddress", type = "Edm.String", retrievable = true, filterable = false, sortable = false, facetable = false, searchable = true },
          { name = "City", type = "Edm.String", retrievable = true, searchable = true, filterable = true, sortable = true, facetable = true },
          { name = "StateProvince", type = "Edm.String", retrievable = true, searchable = true, filterable = true, sortable = true, facetable = true }
        ]
      }
    ],
    suggesters      = [],
    scoringProfiles = [],
  })
}

resource "null_resource" "create_index" {
  depends_on = [
    azurerm_search_service.search,
    azurerm_role_assignment.search_service_contributor,
  ]

  triggers = {
    index_name   = var.index_name
    api_version  = var.api_version
    endpoint     = local.search_endpoint
    content_hash = sha256(local.hotels_index_definition)
    script_hash  = filesha256("${path.module}/create-index.ps1")
  }

  provisioner "local-exec" {
    command     = "& '${path.module}/create-index.ps1'"
    interpreter = ["pwsh", "-NoProfile", "-NonInteractive", "-Command"]
    environment = {
      SEARCH_INDEX_ENDPOINT   = "${local.search_endpoint}/indexes/${var.index_name}?api-version=${var.api_version}"
      SEARCH_INDEX_DEFINITION = local.hotels_index_definition
      AZURE_SUBSCRIPTION_ID   = data.azurerm_client_config.current.subscription_id
    }
  }
}

output "index_create_endpoint" {
  value = "${local.search_endpoint}/indexes/${var.index_name}?api-version=${var.api_version}"
}
