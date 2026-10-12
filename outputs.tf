output "resource_group_name" {
  description = "Groupe de ressources créé pour le lab."
  value       = azurerm_resource_group.rg.name
}

output "vnet_id" {
  description = "ID du réseau virtuel."
  value       = azurerm_virtual_network.vnet.id
}

output "subnet_ids" {
  description = "IDs des sous-réseaux, disponibles une fois leurs NSG associés."
  value = {
    app  = azurerm_subnet.subnet_app.id
    data = azurerm_subnet.subnet_data.id
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.app,
    azurerm_subnet_network_security_group_association.data,
  ]
}

output "network_cidrs" {
  description = "Plan d'adressage calculé."
  value = {
    vnet = var.vnet_cidr
    app  = local.app_cidr
    data = local.data_cidr
  }
}
