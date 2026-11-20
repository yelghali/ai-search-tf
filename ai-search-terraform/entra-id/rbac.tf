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
