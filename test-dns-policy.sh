#!/bin/bash

# Azure DNS Security Policy & Private Resolver Lab - Testing Instructions
# This script provides instructions for testing both the DNS security policy
# and private resolver with on-prem DNS forwarding via Azure Portal Serial Console

echo "============================================================"
echo "Azure DNS Security Policy & Private Resolver Lab - Testing"
echo "============================================================"

# Check if answers.json exists
if [[ ! -f "answers.json" ]]; then
    echo "Error: answers.json file not found."
    exit 1
fi

# Read configuration from answers.json
SUBSCRIPTION_ID=$(jq -r '.subscriptionId' answers.json)
RESOURCE_GROUP_NAME=$(jq -r '.resourceGroupName' answers.json)
VM_NAME=$(jq -r '.vmName' answers.json)
VM_ADMIN_USERNAME=$(jq -r '.vmAdminUsername' answers.json)
DNS_SERVER_VM_NAME=$(jq -r '.dnsServerVmName' answers.json)
DNS_SERVER_STATIC_IP=$(jq -r '.dnsServerStaticIp' answers.json)
ONPREM_CLIENT_VM_NAME=$(jq -r '.onpremClientVmName' answers.json)
RESOLVER_NAME=$(jq -r '.resolverName' answers.json)
PE_NAME=$(jq -r '.privateEndpointName' answers.json)
PRIVATE_DNS_ZONE_NAME=$(jq -r '.privateDnsZoneName' answers.json)

echo "Lab Configuration:"
echo "----------------"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "DNS Security Policy VM: $VM_NAME"
echo "Windows DNS Server: $DNS_SERVER_VM_NAME (IP: $DNS_SERVER_STATIC_IP)"
echo "On-Prem Client: $ONPREM_CLIENT_VM_NAME"
echo "VM Username: $VM_ADMIN_USERNAME"
echo ""

echo "============================================================"
echo "DEMO 1: DNS Security Policy Testing"
echo "============================================================"
echo ""
echo "🔗 Step 1: Access the VM via Serial Console"
echo "-------------------------------------------"
echo "1. Open the Azure Portal: https://portal.azure.com"
echo "2. Navigate to 'Virtual Machines'"
echo "3. Find and click on VM: $VM_NAME"
echo "4. In the left menu under 'Help', click 'Serial console'"
echo "5. Wait for the console to load"
echo "6. Press Enter if needed to get a login prompt"
echo "7. Login with:"
echo "   Username: $VM_ADMIN_USERNAME"
echo "   Password: [The password you provided during deployment]"
echo ""

echo "🧪 Step 2: Test DNS Blocking (run these commands in the serial console)"
echo "----------------------------------------------------------------------"
echo ""
echo "Test blocked domains (these should FAIL):"
echo "nslookup malicious.contoso.com"
echo "nslookup exploit.adatum.com"
echo ""
echo "Expected result: Both queries should fail with 'server can't find' or similar error"
echo ""

echo "Test allowed domains (these should SUCCEED):"
echo "nslookup google.com"
echo "nslookup microsoft.com"
echo "nslookup 8.8.8.8"
echo ""
echo "Expected result: These queries should return valid IP addresses"
echo ""

echo "🔍 Step 3: Verify DNS Security Policy is Working"
echo "-----------------------------------------------"
echo "✅ If blocked domains fail to resolve: DNS Security Policy is working correctly"
echo "❌ If blocked domains resolve successfully: Check the policy configuration"
echo ""

echo "📋 Additional Testing Commands (optional)"
echo "----------------------------------------"
echo "Check current DNS servers:"
echo "cat /etc/resolv.conf"
echo ""
echo "Test with dig (if available):"
echo "dig malicious.contoso.com"
echo "dig google.com"
echo ""
echo "Check network connectivity:"
echo "ping 8.8.8.8"
echo ""

echo "🛠️  Troubleshooting"
echo "------------------"
echo "If the serial console doesn't respond:"
echo "1. Wait a few minutes for the VM to fully boot"
echo "2. Press Enter or Space to activate the console"
echo "3. Try restarting the VM from the Azure Portal"
echo ""
echo "If DNS tests don't work as expected:"
echo "1. Verify the VM is in the correct VNet"
echo "2. Check that the DNS Security Policy is linked to the VNet"
echo "3. Confirm the DNS Security Rule is enabled"
echo ""

echo ""
echo "============================================================"
echo "DEMO 2: Private Resolver & On-Prem DNS Forwarding"
echo "============================================================"
echo ""
echo "🔗 Step 4: Access the On-Prem Client VM via Serial Console"
echo "-----------------------------------------------------------"
echo "1. In the Azure Portal, navigate to Virtual Machines"
echo "2. Find and click on VM: $ONPREM_CLIENT_VM_NAME"
echo "3. Click 'Serial console' under 'Help'"
echo "4. Login with:"
echo "   Username: $VM_ADMIN_USERNAME"
echo "   Password: [The password you provided during deployment]"
echo ""

echo "🧪 Step 5: Test Private Endpoint Resolution (from on-prem client)"
echo "---------------------------------------------------------------"
echo ""
echo "From the on-prem client, the resolution path is:"
echo "  Client -> Windows DNS Server ($DNS_SERVER_STATIC_IP) -> Private Resolver -> Private DNS Zone"
echo ""
echo "Run these commands to test:"
echo "nslookup <storage-account-name>.blob.core.windows.net"
echo "  # Should return a PRIVATE IP address (10.0.3.x)"
echo "  # NOT a public IP address"
echo ""
echo "To find the storage account name, check the deployment output"
echo "or run: az storage account list -g $RESOURCE_GROUP_NAME --query \"[?tags.Role=='PrivateEndpoint-Demo'].name\" -o tsv"
echo ""
echo "Verify the DNS path:"
echo "nslookup <storage-account-name>.blob.core.windows.net $DNS_SERVER_STATIC_IP"
echo "  # This explicitly queries the Windows DNS Server"
echo ""

echo "🔍 Step 6: Verify the Full DNS Chain"
echo "------------------------------------"
echo "✅ If nslookup returns a private IP (10.0.3.x): Full chain works!"
echo "   Client -> Windows DNS -> Conditional Forwarder -> Private Resolver -> Private DNS Zone"
echo "❌ If nslookup returns a public IP: Conditional forwarder may not be configured"
echo "❌ If nslookup fails: Check VNet peering and DNS server configuration"
echo ""

echo "🖥️  Step 7: (Optional) Verify Windows DNS Server Configuration"
echo "--------------------------------------------------------------"
echo "1. In the Azure Portal, find VM: $DNS_SERVER_VM_NAME"
echo "2. Click 'Serial console' under 'Help'"
echo "3. Windows SAC console: type 'cmd' then 'ch -si 1'"
echo "4. Login with:"
echo "   Username: $VM_ADMIN_USERNAME"
echo "   Password: [The password you provided during deployment]"
echo ""
echo "Check conditional forwarders:"
echo "powershell -Command \"Get-DnsServerZone | Where-Object ZoneType -eq 'Forwarder'\""
echo "  # Should show blob.core.windows.net forwarding to the resolver inbound IP"
echo ""
echo "Check DNS server forwarders:"
echo "powershell -Command \"Get-DnsServerForwarder\""
echo ""

# Check if we can get additional info about the deployment
echo "🔧 Lab Status Check"
echo "------------------"
if az account show &> /dev/null; then
    echo "Checking lab deployment status..."
    
    # Check if resource group exists
    if az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null 2>&1; then
        echo "✅ Resource group '$RESOURCE_GROUP_NAME' exists"
        
        # Check if VM exists
        if az vm show --resource-group "$RESOURCE_GROUP_NAME" --name "$VM_NAME" &> /dev/null 2>&1; then
            VM_STATUS=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP_NAME" --name "$VM_NAME" --query instanceView.statuses[1].displayStatus -o tsv 2>/dev/null)
            echo "✅ VM '$VM_NAME' exists - Status: $VM_STATUS"
        else
            echo "❌ VM '$VM_NAME' not found"
        fi
        
        # Check if DNS policy exists
        if az dns-resolver policy show --resource-group "$RESOURCE_GROUP_NAME" --name "dns-security-policy-lab" &> /dev/null 2>&1; then
            echo "✅ DNS Security Policy exists"
        else
            echo "❌ DNS Security Policy not found"
        fi

        # Check if Private Resolver exists
        if az dns-resolver show --resource-group "$RESOURCE_GROUP_NAME" --name "$RESOLVER_NAME" &> /dev/null 2>&1; then
            RESOLVER_STATE=$(az dns-resolver show --resource-group "$RESOURCE_GROUP_NAME" --name "$RESOLVER_NAME" --query provisioningState -o tsv 2>/dev/null)
            echo "✅ DNS Private Resolver '$RESOLVER_NAME' exists - State: $RESOLVER_STATE"
        else
            echo "❌ DNS Private Resolver '$RESOLVER_NAME' not found"
        fi

        # Check if Windows DNS Server VM exists
        if az vm show --resource-group "$RESOURCE_GROUP_NAME" --name "$DNS_SERVER_VM_NAME" &> /dev/null 2>&1; then
            DNS_VM_STATUS=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP_NAME" --name "$DNS_SERVER_VM_NAME" --query instanceView.statuses[1].displayStatus -o tsv 2>/dev/null)
            echo "✅ Windows DNS Server '$DNS_SERVER_VM_NAME' exists - Status: $DNS_VM_STATUS"
        else
            echo "❌ Windows DNS Server '$DNS_SERVER_VM_NAME' not found"
        fi

        # Check if On-Prem Client VM exists
        if az vm show --resource-group "$RESOURCE_GROUP_NAME" --name "$ONPREM_CLIENT_VM_NAME" &> /dev/null 2>&1; then
            CLIENT_VM_STATUS=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP_NAME" --name "$ONPREM_CLIENT_VM_NAME" --query instanceView.statuses[1].displayStatus -o tsv 2>/dev/null)
            echo "✅ On-Prem Client '$ONPREM_CLIENT_VM_NAME' exists - Status: $CLIENT_VM_STATUS"
        else
            echo "❌ On-Prem Client '$ONPREM_CLIENT_VM_NAME' not found"
        fi

        # Check if Private Endpoint exists
        if az network private-endpoint show --resource-group "$RESOURCE_GROUP_NAME" --name "$PE_NAME" &> /dev/null 2>&1; then
            PE_IP=$(az network private-endpoint show --resource-group "$RESOURCE_GROUP_NAME" --name "$PE_NAME" --query "customDnsConfigurations[0].ipAddresses[0]" -o tsv 2>/dev/null)
            echo "✅ Private Endpoint '$PE_NAME' exists - IP: $PE_IP"
        else
            echo "❌ Private Endpoint '$PE_NAME' not found"
        fi

        # Check if Private DNS Zone exists
        if az network private-dns zone show --resource-group "$RESOURCE_GROUP_NAME" --name "$PRIVATE_DNS_ZONE_NAME" &> /dev/null 2>&1; then
            echo "✅ Private DNS Zone '$PRIVATE_DNS_ZONE_NAME' exists"
        else
            echo "❌ Private DNS Zone '$PRIVATE_DNS_ZONE_NAME' not found"
        fi
    else
        echo "❌ Resource group '$RESOURCE_GROUP_NAME' not found"
        echo "   Make sure you've run the deployment script first: ./deploy-lab.sh"
    fi
else
    echo "ℹ️  Not logged into Azure CLI - unable to check deployment status"
    echo "   Log in with: az login --use-device-code"
fi

echo ""
echo "=========================================="
echo "Happy Testing! 🚀"
echo "=========================================="
echo ""
echo "For more help, refer to the lab documentation in README.md"
echo ""
