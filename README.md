# cloudflare-magic-transit-azure

This repository demonstrates how to expose internal Azure endpoints to the internet using [Cloudflare Magic Transit](https://developers.cloudflare.com/magic-transit/).
Cloudflare Magic Transit offers L3-L4-Anti-DDoS-Protection without TLS-Interception - it just routes the traffic to Azure.

## Architecture
- Customer IP prefixes are onboarded to Cloudflare Magic Transit (or use CF leased IPs like this example does)
- Establish tunnels from Cloudflare to Azure (using active-active IPSEC, based on [this guide](https://developers.cloudflare.com/magic-wan/configuration/manually/third-party/azure/azure-vpn-gateway/))
- Configure the BYOD/Cloudflare leased IPs on the internal Azure endpoints (in this case, a private LB fronting an AKS cluster)

## Deployment

```bash 
# prepare the configuration file:
cat > secrets.auto.tfvars <<EOF
azure_subscription_id = "<insert azure subscription id>"
azure_target_resource_group = "<insert existing azure resource group>"
cloudflare_account_id = "<insert cloudflare account ID>"
cloudflare_api_token = "<insert cloudflare API token with permissions to write on Magic WAN>"
cloudflare_gateway_ip = "<insert cloudflare IPSEC gateway IP as provided by Cloudflare account team>"

# set which public IP to use:
# Option 1: a CF leased IP:
azure_public_ip_lb = "104.31.3.8" # the leased IP
cloudflare_public_ips_cidr = "104.31.3.8/32" # route the leased IP to Azure
azure_public_ips_cidr = "104.31.3.0/28" # choose a subnet containing the IP which is at least /29 (requirement Azure)

# Option 2: a whole BYO IP range (untested, but should work):
azure_public_ip_lb = "11.0.0.10" # pick a random IP after .4 which are reserved by Azure
cloudflare_public_ips_cidr = "11.0.0.10/24"
azure_public_ips_cidr = "11.0.0.10/24"

EOF

az login # log in with a user that has access to create the Azure resources (VNet, Subnets, VMs, Bastion, VPN gateway & AKS)

terraform init
terraform apply
...

# when deployed, verify that it works:
curl 104.31.3.8:8000/ip # leased ip
curl 11.0.0.10:8000/ip # ip from BYO range

# should show your external real IP, for example:
{
  "origin": "178.197.x.y:43062"
}
```


## Debugging

- Run `kubectl get pods` and `kubectl describe svc httpin` to see if the Kubernetes side comes up healthy
- Check that the VPN gateway connection on Azure side is showing Status `Connected`.
- Check that the tunnel health check in the Cloudflare dashboard for both tunnels are healthy.
- On the Azure side, there is also a Debug/Diag VM deployed, which can be accessed using the deployed Bastion host (the SSH private key for the `azureuser` login is generated to this directory). Check if routing/tunnels work by curling something from the Internet.



