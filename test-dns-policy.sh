#!/bin/bash

# Azure DNS Security Policy Lab - Testing Instructions
# This script provides instructions for testing the DNS security policy via Azure Portal Serial Console

echo "=========================================="
echo "Azure DNS Security Policy Lab - Testing"
echo "=========================================="

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

echo "Lab Configuration:"
echo "----------------"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "VM Name: $VM_NAME"
echo "VM Username: $VM_ADMIN_USERNAME"
echo ""

echo "Testing Instructions:"
echo "===================="
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
