#!/bin/bash

# Azure DNS Security Policy & Private Resolver Lab - Environment Validation Script
# This script validates the environment before deployment in GitHub Codespaces

echo "================================================================"
echo "Azure DNS Security Policy & Private Resolver Lab - Validation"
echo "================================================================"

EXIT_CODE=0

# Function to check if a command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo "✅ $1 is available"
    else
        echo "❌ $1 is not available"
        EXIT_CODE=1
    fi
}

# Function to validate JSON file
validate_json() {
    if [[ -f "$1" ]]; then
        if jq empty "$1" &> /dev/null; then
            echo "✅ $1 is valid JSON"
        else
            echo "❌ $1 is invalid JSON"
            EXIT_CODE=1
        fi
    else
        echo "❌ $1 not found"
        EXIT_CODE=1
    fi
}

# Check tools (available in GitHub Codespaces devcontainer)
echo ""
echo "Checking Available Tools:"
echo "------------------------"
check_command "az"
check_command "jq"
check_command "bash"

# Check Azure CLI login status
echo ""
echo "Checking Azure CLI Status:"
echo "-------------------------"
if az account show &> /dev/null; then
    CURRENT_SUB=$(az account show --query name -o tsv 2>/dev/null)
    CURRENT_SUB_ID=$(az account show --query id -o tsv 2>/dev/null)
    echo "✅ Logged into Azure"
    echo "   Current subscription: $CURRENT_SUB"
    echo "   Subscription ID: $CURRENT_SUB_ID"
else
    echo "ℹ️  Not currently logged into Azure CLI"
    echo "   The deployment script will handle Azure login with device code"
fi

# Validate answers.json
echo ""
echo "Validating Configuration:"
echo "------------------------"
validate_json "answers.json"

if [[ -f "answers.json" ]]; then
    # Check required fields
    SUBSCRIPTION_ID=$(jq -r '.subscriptionId' answers.json 2>/dev/null)
    RESOURCE_GROUP_NAME=$(jq -r '.resourceGroupName' answers.json 2>/dev/null)
    LOCATION=$(jq -r '.location' answers.json 2>/dev/null)
    
    if [[ -n "$SUBSCRIPTION_ID" && "$SUBSCRIPTION_ID" != "null" && "$SUBSCRIPTION_ID" != "" ]]; then
        echo "✅ subscriptionId is configured"
        
        # Check if the subscription ID matches current Azure CLI context
        if az account show &> /dev/null; then
            CURRENT_SUB_ID=$(az account show --query id -o tsv 2>/dev/null)
            if [[ "$SUBSCRIPTION_ID" == "$CURRENT_SUB_ID" ]]; then
                echo "✅ subscriptionId matches current Azure CLI context"
            else
                echo "ℹ️  subscriptionId ($SUBSCRIPTION_ID) differs from current Azure CLI context ($CURRENT_SUB_ID)"
                echo "   The deployment script will set the correct context"
            fi
        fi
    else
        echo "❌ subscriptionId is required in answers.json"
        EXIT_CODE=1
    fi
    
    if [[ -n "$RESOURCE_GROUP_NAME" && "$RESOURCE_GROUP_NAME" != "null" ]]; then
        echo "✅ resourceGroupName is configured: $RESOURCE_GROUP_NAME"
    else
        echo "❌ resourceGroupName is required in answers.json"
        EXIT_CODE=1
    fi
    
    if [[ -n "$LOCATION" && "$LOCATION" != "null" ]]; then
        echo "✅ location is configured: $LOCATION"
        
        # Check if location is valid (if Azure CLI is logged in)
        if az account show &> /dev/null; then
            if az account list-locations --query "[?name=='$LOCATION']" | jq -e '. | length > 0' &> /dev/null; then
                echo "✅ location '$LOCATION' is valid"
            else
                echo "⚠️  location '$LOCATION' may not be valid"
                echo "   Run 'az account list-locations --output table' to see available locations"
            fi
        fi
    else
        echo "❌ location is required in answers.json"
        EXIT_CODE=1
    fi

    # Validate Private Resolver & On-Prem configuration
    echo ""
    echo "Validating Private Resolver & On-Prem Configuration:"
    echo "---------------------------------------------------"

    ONPREM_VNET_NAME=$(jq -r '.onpremVnetName' answers.json 2>/dev/null)
    RESOLVER_NAME=$(jq -r '.resolverName' answers.json 2>/dev/null)
    DNS_SERVER_VM_NAME=$(jq -r '.dnsServerVmName' answers.json 2>/dev/null)
    ONPREM_CLIENT_VM_NAME=$(jq -r '.onpremClientVmName' answers.json 2>/dev/null)
    PE_NAME=$(jq -r '.privateEndpointName' answers.json 2>/dev/null)
    PRIVATE_DNS_ZONE_NAME=$(jq -r '.privateDnsZoneName' answers.json 2>/dev/null)

    if [[ -n "$ONPREM_VNET_NAME" && "$ONPREM_VNET_NAME" != "null" ]]; then
        echo "✅ onpremVnetName is configured: $ONPREM_VNET_NAME"
    else
        echo "❌ onpremVnetName is required in answers.json"
        EXIT_CODE=1
    fi

    if [[ -n "$RESOLVER_NAME" && "$RESOLVER_NAME" != "null" ]]; then
        echo "✅ resolverName is configured: $RESOLVER_NAME"
    else
        echo "❌ resolverName is required in answers.json"
        EXIT_CODE=1
    fi

    if [[ -n "$DNS_SERVER_VM_NAME" && "$DNS_SERVER_VM_NAME" != "null" ]]; then
        echo "✅ dnsServerVmName is configured: $DNS_SERVER_VM_NAME"
    else
        echo "❌ dnsServerVmName is required in answers.json"
        EXIT_CODE=1
    fi

    if [[ -n "$ONPREM_CLIENT_VM_NAME" && "$ONPREM_CLIENT_VM_NAME" != "null" ]]; then
        echo "✅ onpremClientVmName is configured: $ONPREM_CLIENT_VM_NAME"
    else
        echo "❌ onpremClientVmName is required in answers.json"
        EXIT_CODE=1
    fi

    if [[ -n "$PE_NAME" && "$PE_NAME" != "null" ]]; then
        echo "✅ privateEndpointName is configured: $PE_NAME"
    else
        echo "❌ privateEndpointName is required in answers.json"
        EXIT_CODE=1
    fi

    if [[ -n "$PRIVATE_DNS_ZONE_NAME" && "$PRIVATE_DNS_ZONE_NAME" != "null" ]]; then
        echo "✅ privateDnsZoneName is configured: $PRIVATE_DNS_ZONE_NAME"
    else
        echo "❌ privateDnsZoneName is required in answers.json"
        EXIT_CODE=1
    fi
fi

# Check script permissions
echo ""
echo "Checking Script Permissions:"
echo "---------------------------"
if [[ -x "deploy-lab.sh" ]]; then
    echo "✅ deploy-lab.sh is executable"
else
    echo "⚠️  deploy-lab.sh needs execute permission"
    echo "   Run: chmod +x deploy-lab.sh"
fi

if [[ -x "remove-lab.sh" ]]; then
    echo "✅ remove-lab.sh is executable"
else
    echo "⚠️  remove-lab.sh needs execute permission"
    echo "   Run: chmod +x remove-lab.sh"
fi

# Codespace-specific information
echo ""
echo "GitHub Codespaces Environment:"
echo "-----------------------------"
if [[ -n "$CODESPACES" ]]; then
    echo "✅ Running in GitHub Codespaces"
    echo "   All required tools are pre-installed"
else
    echo "ℹ️  Not running in GitHub Codespaces"
    echo "   Ensure Azure CLI and jq are installed"
fi

# Final status
echo ""
echo "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ VALIDATION PASSED"
    echo "=========================================="
    echo ""
    echo "Your environment is ready for deployment!"
    echo ""
    echo "Next steps:"
    echo "1. Run './deploy-lab.sh' to start the lab deployment"
    echo "2. After deployment, access VMs via Azure Portal Serial Console"
    echo ""
    echo "Demo 1 - DNS Security Policy:"
    echo "  From vm-ubuntu-lab: nslookup malicious.contoso.com (should be blocked)"
    echo ""
    echo "Demo 2 - Private Resolver:"
    echo "  From vm-onprem-client: nslookup <storage>.blob.core.windows.net (should return private IP)"
    echo ""
    echo "3. Clean up with './remove-lab.sh' when done"
else
    echo "❌ VALIDATION FAILED"
    echo "=========================================="
    echo ""
    echo "Please fix the issues above before running the deployment."
fi

echo ""

exit $EXIT_CODE
