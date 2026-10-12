mock_provider "azurerm" {}

run "closed_defaults_and_data_isolation" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for nsg in [azurerm_network_security_group.nsg_app, azurerm_network_security_group.nsg_data] : [
        for direction in ["Inbound", "Outbound"] : anytrue([
          for rule in nsg.security_rule :
          rule.direction == direction && rule.access == "Deny" &&
          rule.protocol == "*" && rule.source_address_prefix == "*" &&
          rule.destination_address_prefix == "*" && rule.source_port_range == "*" &&
          rule.destination_port_range == "*" && rule.priority == 4096
        ])
      ]
    ]))
    error_message = "Chaque NSG doit refuser tout autre flux avant les autorisations Azure par défaut."
  }

  assert {
    condition = alltrue([
      for rule in azurerm_network_security_group.nsg_app.security_rule :
      rule.access != "Allow" || (
        rule.direction == "Outbound" && rule.protocol == "Tcp" &&
        rule.source_address_prefix == "10.0.1.0/24" &&
        rule.destination_address_prefix == "10.0.2.0/24" &&
        rule.destination_port_range == "5432" && rule.priority < 4096
      )
    ])
    error_message = "Par défaut, app ne doit autoriser que les connexions vers data sur TCP 5432."
  }

  assert {
    condition = alltrue([
      for rule in azurerm_network_security_group.nsg_data.security_rule :
      rule.access != "Allow" || (
        rule.direction == "Inbound" && rule.protocol == "Tcp" &&
        rule.source_address_prefix == "10.0.1.0/24" &&
        rule.destination_address_prefix == "10.0.2.0/24" &&
        rule.destination_port_range == "5432" && rule.priority < 4096
      )
    ])
    error_message = "Data ne doit accepter que TCP 5432 depuis app et ne doit initier aucune connexion."
  }

  assert {
    condition = (
      !azurerm_subnet.subnet_app.default_outbound_access_enabled &&
      !azurerm_subnet.subnet_data.default_outbound_access_enabled
    )
    error_message = "La sortie Internet implicite doit être désactivée sur les deux sous-réseaux."
  }
}

run "custom_addressing_and_explicit_https" {
  command = plan

  variables {
    prefix             = "cv-dev"
    vnet_cidr          = "172.20.0.0/16"
    https_source_cidrs = ["10.42.0.0/24", "192.168.1.4/32", "172.16.0.0/12"]
  }

  assert {
    condition = (
      azurerm_resource_group.rg.name == "cv-dev-rg" &&
      output.network_cidrs.app == "172.20.1.0/24" &&
      output.network_cidrs.data == "172.20.2.0/24"
    )
    error_message = "Les noms et les deux sous-réseaux doivent suivre les paramètres du lab."
  }

  assert {
    condition = (
      length([for rule in azurerm_network_security_group.nsg_app.security_rule : rule if rule.direction == "Inbound" && rule.access == "Allow"]) == 1 &&
      anytrue([
        for rule in azurerm_network_security_group.nsg_app.security_rule :
        rule.direction == "Inbound" && rule.access == "Allow" &&
        rule.protocol == "Tcp" && rule.destination_port_range == "443" &&
        rule.destination_address_prefix == "172.20.1.0/24" &&
        toset(rule.source_address_prefixes) == toset(["10.42.0.0/24", "192.168.1.4/32", "172.16.0.0/12"]) &&
        rule.priority < 4096
      ])
    )
    error_message = "HTTPS doit être limité aux sources demandées et au sous-réseau app."
  }

  assert {
    condition = alltrue([
      for path in [
        { rules = azurerm_network_security_group.nsg_app.security_rule, direction = "Outbound" },
        { rules = azurerm_network_security_group.nsg_data.security_rule, direction = "Inbound" }
        ] : anytrue([
          for rule in path.rules :
          rule.direction == path.direction && rule.access == "Allow" &&
          rule.protocol == "Tcp" && rule.source_address_prefix == "172.20.1.0/24" &&
          rule.destination_address_prefix == "172.20.2.0/24" &&
          rule.destination_port_range == "5432" && rule.priority < 4096
      ])
    ])
    error_message = "Le flux PostgreSQL doit être autorisé côté source ET destination, avec les CIDR calculés."
  }
}

# Apply reste simulé : il permet de vérifier les IDs générés et les associations.
run "each_subnet_has_its_own_nsg" {
  command = apply

  # AzureRM valide le format des IDs même lorsque les appels Azure sont simulés.
  override_resource {
    target = azurerm_subnet.subnet_app
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/demo-sec-rg/providers/Microsoft.Network/virtualNetworks/demo-sec-vnet/subnets/app-subnet"
    }
  }
  override_resource {
    target = azurerm_subnet.subnet_data
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/demo-sec-rg/providers/Microsoft.Network/virtualNetworks/demo-sec-vnet/subnets/data-subnet"
    }
  }
  override_resource {
    target = azurerm_network_security_group.nsg_app
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/demo-sec-rg/providers/Microsoft.Network/networkSecurityGroups/demo-sec-nsg"
    }
  }
  override_resource {
    target = azurerm_network_security_group.nsg_data
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/demo-sec-rg/providers/Microsoft.Network/networkSecurityGroups/demo-sec-data-nsg"
    }
  }

  assert {
    condition = (
      azurerm_subnet_network_security_group_association.app.subnet_id == azurerm_subnet.subnet_app.id &&
      azurerm_subnet_network_security_group_association.app.network_security_group_id == azurerm_network_security_group.nsg_app.id &&
      azurerm_subnet_network_security_group_association.data.subnet_id == azurerm_subnet.subnet_data.id &&
      azurerm_subnet_network_security_group_association.data.network_security_group_id == azurerm_network_security_group.nsg_data.id &&
      output.subnet_ids.app == azurerm_subnet.subnet_app.id &&
      output.subnet_ids.data == azurerm_subnet.subnet_data.id &&
      output.subnet_ids.app != output.subnet_ids.data
    )
    error_message = "Chaque sous-réseau doit être associé au bon NSG, et les outputs doivent être distincts."
  }
}
