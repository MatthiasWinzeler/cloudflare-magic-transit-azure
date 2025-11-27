resource "random_password" "gw_psk" {
  length  = 32
  special = false
}

resource "cloudflare_magic_wan_ipsec_tunnel" "azure_gw_1" {
  account_id          = var.cloudflare_account_id
  cloudflare_endpoint = var.cloudflare_gateway_ip
  interface_address = "${cidrhost(var.cloudflare_interface_net_1, 1)}/31" // azure peer + /31, i.e. 10.252.1.55/31
  name                = "${var.azure_prefix}-azure-1"
  description         = "1st tunnel to azure"

  customer_endpoint = azurerm_public_ip.gw_1.ip_address

  health_check = {
    direction = "bidirectional"
    enabled   = true
    rate      = "mid"
    target = {
      saved = azurerm_public_ip.gw_1.ip_address
    }
    type = "reply"
  }

  psk               = random_password.gw_psk.result
  replay_protection = true
}

resource "cloudflare_magic_wan_ipsec_tunnel" "azure_gw_2" {
  account_id          = var.cloudflare_account_id
  cloudflare_endpoint = var.cloudflare_gateway_ip
  interface_address = "${cidrhost(var.cloudflare_interface_net_2, 1)}/31" // azure peer + /31, i.e. 10.252.2.55/31
  name                = "${var.azure_prefix}-azure-2"
  description         = "2nd tunnel to azure"

  customer_endpoint = azurerm_public_ip.gw_2.ip_address

  health_check = {
    direction = "bidirectional"
    enabled   = true
    rate      = "mid"
    target = {
      saved = azurerm_public_ip.gw_2.ip_address
    }
    type = "reply"
  }

  psk               = random_password.gw_psk.result
  replay_protection = true
}

resource "cloudflare_magic_wan_static_route" "azure_1" {
  account_id  = var.cloudflare_account_id
  nexthop = cidrhost(var.cloudflare_interface_net_1, 1) // cloudflare peer, i.e. 10.252.1.54
  prefix      = var.cloudflare_public_ips_cidr
  priority    = 100
  description = "public prefix to azure (1)"

  depends_on = [cloudflare_magic_wan_ipsec_tunnel.azure_gw_1]
}

resource "cloudflare_magic_wan_static_route" "azure_2" {
  account_id  = var.cloudflare_account_id
  nexthop = cidrhost(var.cloudflare_interface_net_2, 1) // cloudflare peer, i.e. 10.252.2.54
  prefix      = var.cloudflare_public_ips_cidr
  priority    = 100
  description = "public prefix to azure (2)"

  depends_on = [cloudflare_magic_wan_ipsec_tunnel.azure_gw_2]
}


resource "cloudflare_magic_wan_static_route" "azure_private_1" {
  account_id  = var.cloudflare_account_id
  nexthop = cidrhost(var.cloudflare_interface_net_1, 1) // cloudflare peer, i.e. 10.252.1.54
  prefix      = var.azure_vnet_cidr
  priority    = 100
  description = "private prefix to azure (1)"

  depends_on = [cloudflare_magic_wan_ipsec_tunnel.azure_gw_1]
}

resource "cloudflare_magic_wan_static_route" "azure_private_2" {
  account_id  = var.cloudflare_account_id
  nexthop = cidrhost(var.cloudflare_interface_net_2, 1) // cloudflare peer, i.e. 10.252.2.54
  prefix      = var.azure_vnet_cidr
  priority    = 100
  description = "private prefix to azure (2)"

  depends_on = [cloudflare_magic_wan_ipsec_tunnel.azure_gw_2]
}