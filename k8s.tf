resource "kubectl_manifest" "httpbin_service" {
  yaml_body = templatefile("${path.module}/httpbin-service.yaml", {
    subnet = azurerm_subnet.aks.name
    ip = var.azure_public_ip_lb
  })
}

resource "kubectl_manifest" "httpbin_deployment" {
  yaml_body = file("${path.module}/httpbin-deployment.yaml")
}
