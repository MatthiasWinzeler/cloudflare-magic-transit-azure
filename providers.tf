terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.53.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "5.12.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.7.2"
    }
    local = {
      source = "hashicorp/local"
      version = "2.6.1"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.1.0"
    }
    kubectl = {
      source = "alekc/kubectl"
      version = "2.1.3"
    }
  }
}


provider "azurerm" {
  subscription_id = var.azure_subscription_id

  resource_provider_registrations = "none"

  features {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "kubectl" {
  host = azurerm_kubernetes_cluster.aks.kube_config.0.host
  username = azurerm_kubernetes_cluster.aks.kube_config.0.username
  password = azurerm_kubernetes_cluster.aks.kube_config.0.password
  client_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)

  load_config_file = false
}
