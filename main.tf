locals {
  app_cidr  = cidrsubnet(var.vnet_cidr, 8, 1)
  data_cidr = cidrsubnet(var.vnet_cidr, 8, 2)
  tags = {
    project     = "azure-secure-landing-zone"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "subnet_app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.app_cidr]

  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "subnet_data" {
  name                 = "data-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.data_cidr]

  default_outbound_access_enabled = false
}
