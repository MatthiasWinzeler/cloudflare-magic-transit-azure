data "kubectl_path_documents" "httpbin" {
  pattern = "${path.module}/httpbin.yaml"
  vars = {
    subnet = azurerm_subnet.aks.name
    ip = var.azure_public_ip_lb
  }
}

resource "kubectl_manifest" "httpbin" {
  for_each = merge(data.kubectl_path_documents.httpbin.manifests[*]...)
  yaml_body = each.value
}
