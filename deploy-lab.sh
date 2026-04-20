#!/bin/bash

# Azure DNS Security Policy & Private Resolver Lab Deployment Script
# This script deploys a complete DNS security policy and private resolver lab environment
# Designed for GitHub Codespaces - no prerequisites required

set -e  # Exit on any error

echo "========================================================"
echo "Azure DNS Security Policy & Private Resolver Lab Deployment"
echo "========================================================"

# Check if answers.json exists
if [[ ! -f "answers.json" ]]; then
    echo "Error: answers.json file not found. Please create it with the required configuration."
    exit 1
fi

# Read configuration from answers.json
SUBSCRIPTION_ID=$(jq -r '.subscriptionId' answers.json)
RESOURCE_GROUP_NAME=$(jq -r '.resourceGroupName' answers.json)
LOCATION=$(jq -r '.location' answers.json)
VNET_NAME=$(jq -r '.vnetName' answers.json)
VNET_ADDRESS_SPACE=$(jq -r '.vnetAddressSpace' answers.json)
SUBNET_NAME=$(jq -r '.subnetName' answers.json)
SUBNET_ADDRESS_PREFIX=$(jq -r '.subnetAddressPrefix' answers.json)
VM_NAME=$(jq -r '.vmName' answers.json)
VM_SIZE=$(jq -r '.vmSize' answers.json)
VM_ADMIN_USERNAME=$(jq -r '.vmAdminUsername' answers.json)
NSG_NAME=$(jq -r '.nsgName' answers.json)
LOG_ANALYTICS_WORKSPACE_NAME=$(jq -r '.logAnalyticsWorkspaceName' answers.json)
DNS_SECURITY_POLICY_NAME=$(jq -r '.dnsSecurityPolicyName' answers.json)
DOMAIN_LIST_NAME=$(jq -r '.domainListName' answers.json)
SECURITY_RULE_NAME=$(jq -r '.securityRuleName' answers.json)
VNET_LINK_NAME=$(jq -r '.vnetLinkName' answers.json)

# Private Resolver & On-Prem configuration
ONPREM_VNET_NAME=$(jq -r '.onpremVnetName' answers.json)
ONPREM_VNET_ADDRESS_SPACE=$(jq -r '.onpremVnetAddressSpace' answers.json)
ONPREM_SUBNET_NAME=$(jq -r '.onpremSubnetName' answers.json)
ONPREM_SUBNET_ADDRESS_PREFIX=$(jq -r '.onpremSubnetAddressPrefix' answers.json)
ONPREM_NSG_NAME=$(jq -r '.onpremNsgName' answers.json)
DNS_SERVER_VM_NAME=$(jq -r '.dnsServerVmName' answers.json)
DNS_SERVER_VM_SIZE=$(jq -r '.dnsServerVmSize' answers.json)
DNS_SERVER_STATIC_IP=$(jq -r '.dnsServerStaticIp' answers.json)
ONPREM_CLIENT_VM_NAME=$(jq -r '.onpremClientVmName' answers.json)
ONPREM_CLIENT_VM_SIZE=$(jq -r '.onpremClientVmSize' answers.json)
RESOLVER_NAME=$(jq -r '.resolverName' answers.json)
RESOLVER_INBOUND_SUBNET_NAME=$(jq -r '.resolverInboundSubnetName' answers.json)
RESOLVER_INBOUND_SUBNET_PREFIX=$(jq -r '.resolverInboundSubnetPrefix' answers.json)
RESOLVER_INBOUND_ENDPOINT_NAME=$(jq -r '.resolverInboundEndpointName' answers.json)
PE_SUBNET_NAME=$(jq -r '.privateEndpointSubnetName' answers.json)
PE_SUBNET_PREFIX=$(jq -r '.privateEndpointSubnetPrefix' answers.json)
PE_NAME=$(jq -r '.privateEndpointName' answers.json)
PRIVATE_DNS_ZONE_NAME=$(jq -r '.privateDnsZoneName' answers.json)
PRIVATE_DNS_ZONE_LINK_NAME=$(jq -r '.privateDnsZoneLinkName' answers.json)

# Validate required fields
if [[ -z "$SUBSCRIPTION_ID" || "$SUBSCRIPTION_ID" == "null" || "$SUBSCRIPTION_ID" == "" ]]; then
    echo "Error: subscriptionId is required in answers.json"
    exit 1
fi

# Function to validate password requirements
validate_password() {
    local password="$1"
    
    # Check length (12-123 characters)
    if [[ ${#password} -lt 12 || ${#password} -gt 123 ]]; then
        echo "Error: Password must be 12-123 characters long"
        return 1
    fi
    
    # Check for uppercase letter
    if [[ ! "$password" =~ [A-Z] ]]; then
        echo "Error: Password must contain at least one uppercase letter"
        return 1
    fi
    
    # Check for lowercase letter
    if [[ ! "$password" =~ [a-z] ]]; then
        echo "Error: Password must contain at least one lowercase letter"
        return 1
    fi
    
    # Check for number
    if [[ ! "$password" =~ [0-9] ]]; then
        echo "Error: Password must contain at least one number"
        return 1
    fi
    
    # Check for special character
    if [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        echo "Error: Password must contain at least one special character"
        return 1
    fi
    
    return 0
}

# Prompt for VM password with confirmation
echo ""
echo "Password Requirements (used for all VMs - Ubuntu, Windows DNS Server, and on-prem client):"
echo "- Must be 12-123 characters long"
echo "- Must contain uppercase, lowercase, numbers, and special characters"
echo ""
while true; do
    read -s -p "Enter password for all lab VMs (admin user: $VM_ADMIN_USERNAME): " VM_PASSWORD
    echo ""
    
    if [[ -z "$VM_PASSWORD" ]]; then
        echo "Error: VM password cannot be empty"
        continue
    fi
    
    # Validate password requirements
    if ! validate_password "$VM_PASSWORD"; then
        echo ""
        continue
    fi
    
    read -s -p "Confirm password: " VM_PASSWORD_CONFIRM
    echo ""
    
    if [[ "$VM_PASSWORD" == "$VM_PASSWORD_CONFIRM" ]]; then
        echo "Password confirmed successfully."
        break
    else
        echo "Error: Passwords do not match. Please try again."
        echo ""
    fi
done

# Login to Azure with device code
echo ""
echo "Logging into Azure..."
az login --use-device-code

# Configure Azure CLI to allow preview extensions without prompts
echo "Configuring Azure CLI extensions..."
az config set extension.dynamic_install_allow_preview=true
az config set extension.use_dynamic_install=yes_without_prompt

# Set the subscription context
echo "Setting subscription context to: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Verify the subscription is set correctly
CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv)
if [[ "$CURRENT_SUBSCRIPTION" != "$SUBSCRIPTION_ID" ]]; then
    echo "Error: Failed to set subscription context"
    exit 1
fi

echo "Successfully set subscription: $(az account show --query name -o tsv)"

# Create Resource Group
echo ""
echo "Creating resource group: $RESOURCE_GROUP_NAME"
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab" "Environment=Lab"

# Create Log Analytics Workspace
echo ""
echo "Creating Log Analytics workspace: $LOG_ANALYTICS_WORKSPACE_NAME"
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab"

# Create Virtual Network
echo ""
echo "Creating virtual network: $VNET_NAME"
az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --address-prefix "$VNET_ADDRESS_SPACE" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "$SUBNET_ADDRESS_PREFIX" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab"

# Create Network Security Group (minimal rules for internal access only)
echo ""
echo "Creating network security group: $NSG_NAME"
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$NSG_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab"

# Associate NSG with subnet
echo "Associating NSG with subnet"
az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME"

# Create Ubuntu VM (no public IP, access via serial console)
echo ""
echo "Creating Ubuntu VM: $VM_NAME"
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VM_NAME" \
    --image "Ubuntu2204" \
    --admin-username "$VM_ADMIN_USERNAME" \
    --admin-password "$VM_PASSWORD" \
    --authentication-type password \
    --size "$VM_SIZE" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --public-ip-address "" \
    --nsg "" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab"

# Create storage account for boot diagnostics
echo ""
echo "Creating storage account for boot diagnostics..."
STORAGE_ACCOUNT_NAME="sa$(echo $RESOURCE_GROUP_NAME | tr -d '-' | tr '[:upper:]' '[:lower:]')$(date +%s | tail -c 6)"
az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --tags "Purpose=DNS-Security-Lab"

# Enable boot diagnostics
echo ""
echo "Enabling boot diagnostics for VM: $VM_NAME"
az vm boot-diagnostics enable \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VM_NAME" \
    --storage "$STORAGE_ACCOUNT_NAME"

# Create DNS Security Policy
echo ""
echo "Creating DNS security policy: $DNS_SECURITY_POLICY_NAME"
az dns-resolver policy create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DNS_SECURITY_POLICY_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab"

# Get the VNet resource ID for linking
VNET_ID=$(az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --query id -o tsv)

# Create Virtual Network Link to DNS Security Policy
echo ""
echo "Creating virtual network link: $VNET_LINK_NAME"
az dns-resolver policy vnet-link create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --policy-name "$DNS_SECURITY_POLICY_NAME" \
    --name "$VNET_LINK_NAME" \
    --virtual-network "{'id':'$VNET_ID'}" \
    --location "$LOCATION"

# Create DNS Domain List
echo ""
echo "Creating DNS domain list: $DOMAIN_LIST_NAME"
az dns-resolver domain-list create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --dns-resolver-domain-list-name "$DOMAIN_LIST_NAME" \
    --domains "malicious.contoso.com." "exploit.adatum.com." \
    --location "$LOCATION"

# Get the DNS Domain List resource ID
DOMAIN_LIST_ID=$(az dns-resolver domain-list show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --dns-resolver-domain-list-name "$DOMAIN_LIST_NAME" \
    --query id -o tsv)

# Create DNS Security Rule with Block action
echo ""
echo "Creating DNS security rule: $SECURITY_RULE_NAME"
az dns-resolver policy dns-security-rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --policy-name "$DNS_SECURITY_POLICY_NAME" \
    --name "$SECURITY_RULE_NAME" \
    --priority 100 \
    --action "{action-type:Block}" \
    --domain-lists "[{'id':'$DOMAIN_LIST_ID'}]" \
    --rule-state "Enabled" \
    --location "$LOCATION"

# Get Log Analytics Workspace resource ID
echo ""
echo "Getting Log Analytics workspace resource ID..."
LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --query id -o tsv)

# Configure diagnostic settings for DNS Security Policy
echo ""
echo "Configuring diagnostic settings for DNS Security Policy..."
az monitor diagnostic-settings create \
    --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/dnsResolverPolicies/$DNS_SECURITY_POLICY_NAME" \
    --name "dns-policy-diagnostics" \
    --workspace "$LOG_ANALYTICS_WORKSPACE_ID" \
    --logs '[
        {
            "category": "DnsResponse",
            "enabled": true,
            "retentionPolicy": {
                "days": 0,
                "enabled": false
            }
        }
    ]'

# ==========================================
# PRIVATE RESOLVER & ON-PREM DEMO
# ==========================================

echo ""
echo "=========================================="
echo "Deploying Private Resolver & On-Prem Demo"
echo "=========================================="

# Add resolver inbound subnet to hub VNet (delegated to Microsoft.Network/dnsResolvers)
echo ""
echo "Creating resolver inbound subnet: $RESOLVER_INBOUND_SUBNET_NAME"
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$RESOLVER_INBOUND_SUBNET_NAME" \
    --address-prefix "$RESOLVER_INBOUND_SUBNET_PREFIX" \
    --delegations "Microsoft.Network/dnsResolvers"

# Add private endpoint subnet to hub VNet
echo ""
echo "Creating private endpoint subnet: $PE_SUBNET_NAME"
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$PE_SUBNET_NAME" \
    --address-prefix "$PE_SUBNET_PREFIX"

# Disable private endpoint network policies on PE subnet
echo "Disabling private endpoint network policies on subnet: $PE_SUBNET_NAME"
az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$PE_SUBNET_NAME" \
    --private-endpoint-network-policies Disabled

# Create Azure DNS Private Resolver in hub VNet
echo ""
echo "Creating DNS Private Resolver: $RESOLVER_NAME"
az dns-resolver create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$RESOLVER_NAME" \
    --location "$LOCATION" \
    --id "$VNET_ID" \
    --tags "Purpose=DNS-Security-Lab"

# Get resolver inbound subnet ID
RESOLVER_INBOUND_SUBNET_ID=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$RESOLVER_INBOUND_SUBNET_NAME" \
    --query id -o tsv)

# Create inbound endpoint for the Private Resolver
echo ""
echo "Creating resolver inbound endpoint: $RESOLVER_INBOUND_ENDPOINT_NAME"
az dns-resolver inbound-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --dns-resolver-name "$RESOLVER_NAME" \
    --name "$RESOLVER_INBOUND_ENDPOINT_NAME" \
    --location "$LOCATION" \
    --ip-configurations "[{private-ip-allocation-method:Dynamic,id:$RESOLVER_INBOUND_SUBNET_ID}]"

# Get the inbound endpoint IP address
RESOLVER_INBOUND_IP=$(az dns-resolver inbound-endpoint show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --dns-resolver-name "$RESOLVER_NAME" \
    --name "$RESOLVER_INBOUND_ENDPOINT_NAME" \
    --query "ipConfigurations[0].privateIpAddress" -o tsv)

echo "Private Resolver inbound endpoint IP: $RESOLVER_INBOUND_IP"

# --- On-Prem Environment ---

# Create on-prem virtual network
echo ""
echo "Creating on-prem virtual network: $ONPREM_VNET_NAME"
az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ONPREM_VNET_NAME" \
    --address-prefix "$ONPREM_VNET_ADDRESS_SPACE" \
    --subnet-name "$ONPREM_SUBNET_NAME" \
    --subnet-prefix "$ONPREM_SUBNET_ADDRESS_PREFIX" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab" "Environment=OnPrem-Simulated"

# Create on-prem NSG
echo ""
echo "Creating on-prem network security group: $ONPREM_NSG_NAME"
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ONPREM_NSG_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab"

# Associate on-prem NSG with subnet
echo "Associating on-prem NSG with subnet"
az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$ONPREM_VNET_NAME" \
    --name "$ONPREM_SUBNET_NAME" \
    --network-security-group "$ONPREM_NSG_NAME"

# Create VNet peering: hub -> on-prem
echo ""
echo "Creating VNet peering: hub -> on-prem"
ONPREM_VNET_ID=$(az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ONPREM_VNET_NAME" \
    --query id -o tsv)

az network vnet peering create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "hub-to-onprem" \
    --vnet-name "$VNET_NAME" \
    --remote-vnet "$ONPREM_VNET_ID" \
    --allow-vnet-access \
    --allow-forwarded-traffic

# Create VNet peering: on-prem -> hub
echo "Creating VNet peering: on-prem -> hub"
az network vnet peering create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "onprem-to-hub" \
    --vnet-name "$ONPREM_VNET_NAME" \
    --remote-vnet "$VNET_ID" \
    --allow-vnet-access \
    --allow-forwarded-traffic

# Set custom DNS servers on on-prem VNet to the Windows DNS Server
echo ""
echo "Setting on-prem VNet DNS servers to: $DNS_SERVER_STATIC_IP"
az network vnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ONPREM_VNET_NAME" \
    --dns-servers "$DNS_SERVER_STATIC_IP"

# Create Windows DNS Server VM with static private IP
echo ""
echo "Creating Windows DNS Server VM: $DNS_SERVER_VM_NAME"
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DNS_SERVER_VM_NAME" \
    --image "Win2022Datacenter" \
    --admin-username "$VM_ADMIN_USERNAME" \
    --admin-password "$VM_PASSWORD" \
    --authentication-type password \
    --size "$DNS_SERVER_VM_SIZE" \
    --vnet-name "$ONPREM_VNET_NAME" \
    --subnet "$ONPREM_SUBNET_NAME" \
    --private-ip-address "$DNS_SERVER_STATIC_IP" \
    --public-ip-address "" \
    --nsg "" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab" "Role=DNS-Server"

# Configure Windows DNS Server role and conditional forwarder via run-command
echo ""
echo "Configuring Windows DNS Server role and conditional forwarder..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DNS_SERVER_VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "
        # Install DNS Server role
        Install-WindowsFeature DNS -IncludeManagementTools

        # Add conditional forwarder for blob.core.windows.net -> Private Resolver inbound IP
        Add-DnsServerConditionalForwarderZone -Name 'blob.core.windows.net' -MasterServers $RESOLVER_INBOUND_IP -PassThru

        # Verify installation
        Get-WindowsFeature DNS
        Get-DnsServerForwarder
        Get-DnsServerZone
    "

echo "Windows DNS Server configured successfully."

# Create on-prem client VM (Ubuntu) with DNS pointing to Windows DNS Server
echo ""
echo "Creating on-prem client VM: $ONPREM_CLIENT_VM_NAME"
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ONPREM_CLIENT_VM_NAME" \
    --image "Ubuntu2204" \
    --admin-username "$VM_ADMIN_USERNAME" \
    --admin-password "$VM_PASSWORD" \
    --authentication-type password \
    --size "$ONPREM_CLIENT_VM_SIZE" \
    --vnet-name "$ONPREM_VNET_NAME" \
    --subnet "$ONPREM_SUBNET_NAME" \
    --public-ip-address "" \
    --nsg "" \
    --location "$LOCATION" \
    --tags "Purpose=DNS-Security-Lab" "Role=OnPrem-Client"

# Configure on-prem client DNS to use Windows DNS Server via run-command
echo ""
echo "Configuring on-prem client DNS to use Windows DNS Server ($DNS_SERVER_STATIC_IP)..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ONPREM_CLIENT_VM_NAME" \
    --command-id RunShellScript \
    --scripts "
        # Create systemd-resolved drop-in to use Windows DNS Server
        mkdir -p /etc/systemd/resolved.conf.d
        cat > /etc/systemd/resolved.conf.d/dns-lab.conf << DNSEOF
[Resolve]
DNS=$DNS_SERVER_STATIC_IP
Domains=~.
DNSEOF

        # Restart systemd-resolved to apply changes
        systemctl restart systemd-resolved

        # Verify DNS configuration
        resolvectl status
    "

echo "On-prem client DNS configured successfully."

# --- Private Endpoint & Private DNS Zone ---

# Create dedicated storage account for private endpoint demo
echo ""
echo "Creating storage account for private endpoint demo..."
PE_STORAGE_ACCOUNT_NAME="stpvtlink$(date +%s | tail -c 10)"
az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$PE_STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --public-network-access Disabled \
    --allow-blob-public-access false \
    --tags "Purpose=DNS-Security-Lab" "Role=PrivateEndpoint-Demo"

echo "Storage account created: $PE_STORAGE_ACCOUNT_NAME"

# Get storage account resource ID
PE_STORAGE_ACCOUNT_ID=$(az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$PE_STORAGE_ACCOUNT_NAME" \
    --query id -o tsv)

# Create private endpoint for blob storage in PE subnet
echo ""
echo "Creating private endpoint: $PE_NAME"
az network private-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$PE_NAME" \
    --vnet-name "$VNET_NAME" \
    --subnet "$PE_SUBNET_NAME" \
    --private-connection-resource-id "$PE_STORAGE_ACCOUNT_ID" \
    --group-id "blob" \
    --connection-name "pe-connection-storage" \
    --location "$LOCATION"

# Create Private DNS Zone for blob storage
echo ""
echo "Creating Private DNS Zone: $PRIVATE_DNS_ZONE_NAME"
az network private-dns zone create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$PRIVATE_DNS_ZONE_NAME"

# Link Private DNS Zone to hub VNet
echo ""
echo "Linking Private DNS Zone to hub VNet: $PRIVATE_DNS_ZONE_LINK_NAME"
az network private-dns link vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --zone-name "$PRIVATE_DNS_ZONE_NAME" \
    --name "$PRIVATE_DNS_ZONE_LINK_NAME" \
    --virtual-network "$VNET_ID" \
    --registration-enabled false

# Create DNS zone group on private endpoint (auto-registers A record in private DNS zone)
echo ""
echo "Creating DNS zone group for private endpoint..."
az network private-endpoint dns-zone-group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --endpoint-name "$PE_NAME" \
    --name "default" \
    --private-dns-zone "$PRIVATE_DNS_ZONE_NAME" \
    --zone-name "blob"

# Get the private endpoint IP for display
PE_PRIVATE_IP=$(az network private-endpoint show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$PE_NAME" \
    --query "customDnsConfigurations[0].ipAddresses[0]" -o tsv)

echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo ""
echo "Lab Environment Details:"
echo "------------------------"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo ""
echo "--- DNS Security Policy Demo ---"
echo "Virtual Network: $VNET_NAME ($VNET_ADDRESS_SPACE)"
echo "VM Name: $VM_NAME"
echo "VM Username: $VM_ADMIN_USERNAME"
echo "VM Password: [HIDDEN - provided during deployment]"
echo "DNS Security Policy: $DNS_SECURITY_POLICY_NAME"
echo "Domain List: $DOMAIN_LIST_NAME"
echo "Blocked Domains: malicious.contoso.com., exploit.adatum.com."
echo "Security Rule: $SECURITY_RULE_NAME (Priority: 100, Action: Block)"
echo "Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE_NAME"
echo ""
echo "--- Private Resolver Demo ---"
echo "DNS Private Resolver: $RESOLVER_NAME"
echo "Resolver Inbound IP: $RESOLVER_INBOUND_IP"
echo "Storage Account: $PE_STORAGE_ACCOUNT_NAME (public access disabled)"
echo "Private Endpoint: $PE_NAME (IP: $PE_PRIVATE_IP)"
echo "Private DNS Zone: $PRIVATE_DNS_ZONE_NAME"
echo ""
echo "--- On-Prem Environment (Simulated) ---"
echo "On-Prem VNet: $ONPREM_VNET_NAME ($ONPREM_VNET_ADDRESS_SPACE)"
echo "Windows DNS Server: $DNS_SERVER_VM_NAME (IP: $DNS_SERVER_STATIC_IP)"
echo "  - Conditional forwarder: blob.core.windows.net -> $RESOLVER_INBOUND_IP"
echo "On-Prem Client: $ONPREM_CLIENT_VM_NAME (DNS: $DNS_SERVER_STATIC_IP)"
echo "VNet Peering: hub <-> on-prem (Connected)"
echo ""
echo "VM Access Instructions:"
echo "----------------------"
echo "All VMs are accessed via Azure Portal Serial Console."
echo "1. Go to the Azure Portal: https://portal.azure.com"
echo "2. Navigate to Virtual Machines"
echo "3. Select the VM in resource group '$RESOURCE_GROUP_NAME'"
echo "4. Click 'Serial console' in the left menu under 'Help'"
echo "5. Login with username: $VM_ADMIN_USERNAME and the password from deployment"
echo ""
echo "Note: Windows DNS Server ($DNS_SERVER_VM_NAME) uses SAC serial console."
echo "      Type 'cmd' then 'ch -si 1' to access command prompt."
echo ""
echo "--- Test DNS Security Policy (from $VM_NAME) ---"
echo "dig malicious.contoso.com    # Should return: blockpolicy.azuredns.invalid"
echo "dig exploit.adatum.com       # Should return: blockpolicy.azuredns.invalid"
echo "dig google.com               # Should resolve normally"
echo ""
echo "--- Test Private Endpoint Resolution (from $ONPREM_CLIENT_VM_NAME) ---"
echo "nslookup ${PE_STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
echo "  # Should return private IP: $PE_PRIVATE_IP"
echo "  # Resolution path: Client -> Windows DNS -> Private Resolver -> Private DNS Zone"
echo ""
