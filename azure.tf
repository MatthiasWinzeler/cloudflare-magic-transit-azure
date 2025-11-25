data "azurerm_resource_group" "rg" {
  name = var.azure_target_resource_group
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.azure_prefix}-vnet"
  address_space = [var.azure_vnet_cidr, var.azure_public_ips_cidr]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.azure_gateway_cidr]
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.azure_prefix}-aks"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.azure_aks_cidr]
}

resource "azurerm_subnet" "public_ips" {
  name                 = "${var.azure_prefix}-public-ips"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.azure_public_ips_cidr]
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.azure_prefix}-bastion"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Developer"
  virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_network_interface" "client" {
  name                = "${var.azure_prefix}-diagvm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aks.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "tls_private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}

resource "local_file" "tls_private_key" {
  content         = tls_private_key.key.private_key_openssh
  filename        = "${path.module}/id_rsa_diagvm"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "client" {
  name                = "${var.azure_prefix}-diagvm"
  computer_name       = "${var.azure_prefix}-diagvm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  network_interface_ids = [azurerm_network_interface.client.id]
  size                = "Standard_B1ms"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  boot_diagnostics {}


  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.key.public_key_openssh
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.azure_prefix}-aks"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = "${var.azure_prefix}-aks"

  default_node_pool {
    vnet_subnet_id = azurerm_subnet.aks.id
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_D2ds_v5"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    # to not overlap with 10.0/16 VNet range
    service_cidr   = "10.255.0.0/16"
    dns_service_ip = "10.255.0.10"
    network_plugin = "azure"
  }

  identity {
    type = "SystemAssigned"
  }


  kubernetes_version = var.azure_kube_version
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  role_definition_name = "Network Contributor"

  scope                = azurerm_virtual_network.vnet.id
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}


resource "azurerm_public_ip" "gw_1" {
  name                = "${var.azure_prefix}-gw-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  allocation_method = "Static"
  zones = [1, 2, 3]
}

resource "azurerm_public_ip" "gw_2" {
  name                = "${var.azure_prefix}-gw-2"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  allocation_method = "Static"
  zones = [1, 2, 3]
}

resource "azurerm_virtual_network_gateway" "gw" {
  name                = "${var.azure_prefix}-gw"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active              = true
  private_ip_address_enabled = false
  sku                        = "VpnGw2AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.gw_1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.gw_2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

resource "azurerm_local_network_gateway" "cloudflare" {
  name                = "${var.azure_prefix}-cloudflare"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  gateway_address     = var.cloudflare_gateway_ip
  address_space = [
    "0.0.0.0/1",
    "128.0.0.0/1",
    "${cidrhost(var.cloudflare_interface_net_1, 1)}/32",
    // upper IP (azure peer) + /32 of first tunnel, i.e. 10.252.1.55/32
    "${cidrhost(var.cloudflare_interface_net_2, 1)}/32",
    // upper IP (azure peer) + /32 of second tunnel, i.e. 10.252.2.55/32
  ]
}

resource "azurerm_virtual_network_gateway_connection" "cloudflare" {
  name                = "${var.azure_prefix}-cloudflare"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.gw.id
  local_network_gateway_id   = azurerm_local_network_gateway.cloudflare.id

  shared_key = random_password.gw_psk.result

  ipsec_policy {
    ike_encryption = "GCMAES256"
    ike_integrity  = "SHA384"
    dh_group       = "ECP384"

    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "ECP384"

    sa_lifetime = 28800
    sa_datasize = 0
  }

  use_policy_based_traffic_selectors = false
  dpd_timeout_seconds                = 45
  connection_mode                    = "InitiatorOnly"
}