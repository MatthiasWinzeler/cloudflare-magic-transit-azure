variable "azure_public_ip_lb" {
  type = string
  description = "the public IP to use for the Azure LB"
}

variable "azure_public_ips_cidr" {
  type    = string
  description = "the range of public IPs to use for the VNet in Azure. Azure requires this to be at least /29."
}

variable "cloudflare_public_ips_cidr" {
  type = string
  description = "the public IP prefixes to route to Azure."
}

variable "azure_subscription_id" {
  type    = string
}

variable "azure_target_resource_group" {
  type    = string
  description = "name of an existing resource group to deploy the resources to"
}

variable "azure_prefix" {
  type    = string
  default = "cloudflare-test"
}

variable "azure_vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

// GW subnet must be at least /27 according to azure
variable "azure_gateway_cidr" {
  type    = string
  default = "10.0.1.0/27"
}

variable "azure_aks_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "azure_kube_version" {
  type    = string
  default = "1.32.9"
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

variable "cloudflare_gateway_ip" {
  type    = string
  description = "the IP endpoint for IPSEC tunnels, as retrieved from Cloudflare"
}

variable "cloudflare_interface_net_1" {
  type = string
  default = "10.252.1.54/31"
}

variable "cloudflare_interface_net_2" {
  type = string
  default = "10.252.2.54/31"
}

