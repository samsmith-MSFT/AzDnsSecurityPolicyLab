#!/bin/bash

# Azure DNS Security Policy Lab Deployment Script
# This script deploys a complete DNS security policy lab environment
# Designed for GitHub Codespaces - no prerequisites required

set -e  # Exit on any error

echo "=========================================="
echo "Azure DNS Security Policy Lab Deployment"
echo "=========================================="

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

# Validate required fields
if [[ -z "$SUBSCRIPTION_ID" || "$SUBSCRIPTION_ID" == "null" || "$SUBSCRIPTION_ID" == "" ]]; then
    echo "Error: subscriptionId is required in answers.json"
    exit 1
fi

# Prompt for VM password with confirmation
echo ""
while true; do
    read -s -p "Enter password for Ubuntu VM admin user ($VM_ADMIN_USERNAME): " VM_PASSWORD
    echo ""
    
    if [[ -z "$VM_PASSWORD" ]]; then
        echo "Error: VM password cannot be empty"
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

echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo ""
echo "Lab Environment Details:"
echo "------------------------"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
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
echo "VM Access Instructions:"
echo "----------------------"
echo "1. Go to the Azure Portal: https://portal.azure.com"
echo "2. Navigate to Virtual Machines"
echo "3. Select '$VM_NAME' in resource group '$RESOURCE_GROUP_NAME'"
echo "4. Click 'Serial console' in the left menu under 'Help'"
echo "5. Login with username: $VM_ADMIN_USERNAME"
echo "6. Use the password you provided during deployment"
echo ""
echo "To test DNS blocking from the VM serial console, try:"
echo "nslookup malicious.contoso.com"
echo "nslookup exploit.adatum.com"
echo ""
echo "These queries should fail due to the DNS security policy."
echo "Test that normal domains work: nslookup google.com"
echo ""
