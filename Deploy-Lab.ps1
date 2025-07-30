# Azure DNS Security Policy Lab Deployment Script (PowerShell)
# This script deploys a complete DNS security policy lab environment
# Designed for GitHub Codespaces - no prerequisites required

param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Azure DNS Security Policy Lab Deployment" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Check if answers.json exists
if (-not (Test-Path "answers.json")) {
    Write-Error "Error: answers.json file not found. Please create it with the required configuration."
    exit 1
}

# Read configuration from answers.json
try {
    $config = Get-Content "answers.json" | ConvertFrom-Json
} catch {
    Write-Error "Error: Failed to parse answers.json. Please ensure it contains valid JSON."
    exit 1
}

# Extract configuration values
$subscriptionId = $config.subscriptionId
$resourceGroupName = $config.resourceGroupName
$location = $config.location
$vnetName = $config.vnetName
$vnetAddressSpace = $config.vnetAddressSpace
$subnetName = $config.subnetName
$subnetAddressPrefix = $config.subnetAddressPrefix
$vmName = $config.vmName
$vmSize = $config.vmSize
$vmAdminUsername = $config.vmAdminUsername
$nsgName = $config.nsgName
$dnsSecurityPolicyName = $config.dnsSecurityPolicyName
$domainListName = $config.domainListName
$securityRuleName = $config.securityRuleName
$vnetLinkName = $config.vnetLinkName
$logAnalyticsWorkspaceName = $config.logAnalyticsWorkspaceName

# Validate required fields
if ([string]::IsNullOrEmpty($subscriptionId)) {
    Write-Error "Error: subscriptionId is required in answers.json"
    exit 1
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "WHAT-IF MODE: The following resources would be created:" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Resource Group: $resourceGroupName"
    Write-Host "Location: $location"
    Write-Host "Virtual Network: $vnetName"
    Write-Host "VM: $vmName (no public IP, serial console access)"
    Write-Host "DNS Security Policy: $dnsSecurityPolicyName"
    Write-Host "Domain List: $domainListName"
    Write-Host "Security Rule: $securityRuleName"
    Write-Host ""
    Write-Host "Run without -WhatIf to proceed with deployment."
    exit 0
}

# Prompt for VM password
Write-Host ""
$vmPassword = Read-Host "Enter password for Ubuntu VM admin user ($vmAdminUsername)" -AsSecureString
$vmPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vmPassword))

if ([string]::IsNullOrEmpty($vmPasswordText)) {
    Write-Error "Error: VM password cannot be empty"
    exit 1
}

# Login to Azure
Write-Host ""
Write-Host "Logging into Azure..."
try {
    $null = az login --use-device-code
} catch {
    Write-Error "Failed to login to Azure"
    exit 1
}

# Set the subscription context
Write-Host "Setting subscription context to: $subscriptionId"
try {
    $null = az account set --subscription $subscriptionId
    $currentSub = az account show --query name -o tsv
    Write-Host "Successfully set subscription: $currentSub" -ForegroundColor Green
} catch {
    Write-Error "Failed to set subscription context"
    exit 1
}

# Create Resource Group
Write-Host ""
Write-Host "Creating resource group: $resourceGroupName"
$null = az group create --name $resourceGroupName --location $location --tags "Purpose=DNS-Security-Lab" "Environment=Lab"

# Create Log Analytics Workspace
Write-Host ""
Write-Host "Creating Log Analytics workspace: $logAnalyticsWorkspaceName"
$null = az monitor log-analytics workspace create `
    --resource-group $resourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --location $location `
    --tags "Purpose=DNS-Security-Lab"

# Create Virtual Network
Write-Host ""
Write-Host "Creating virtual network: $vnetName"
$null = az network vnet create `
    --resource-group $resourceGroupName `
    --name $vnetName `
    --address-prefix $vnetAddressSpace `
    --subnet-name $subnetName `
    --subnet-prefix $subnetAddressPrefix `
    --location $location `
    --tags "Purpose=DNS-Security-Lab"

# Create Network Security Group (minimal rules for internal access only)
Write-Host ""
Write-Host "Creating network security group: $nsgName"
$null = az network nsg create `
    --resource-group $resourceGroupName `
    --name $nsgName `
    --location $location `
    --tags "Purpose=DNS-Security-Lab"

# Associate NSG with subnet
Write-Host "Associating NSG with subnet"
$null = az network vnet subnet update `
    --resource-group $resourceGroupName `
    --vnet-name $vnetName `
    --name $subnetName `
    --network-security-group $nsgName

# Create Ubuntu VM (no public IP, access via serial console)
Write-Host ""
Write-Host "Creating Ubuntu VM: $vmName"
$null = az vm create `
    --resource-group $resourceGroupName `
    --name $vmName `
    --image "Ubuntu2204" `
    --admin-username $vmAdminUsername `
    --admin-password $vmPasswordText `
    --authentication-type password `
    --size $vmSize `
    --vnet-name $vnetName `
    --subnet $subnetName `
    --public-ip-address '""' `
    --nsg '""' `
    --location $location `
    --disable-password-authentication false `
    --boot-diagnostics-storage '""' `
    --tags "Purpose=DNS-Security-Lab"

# Create DNS Security Policy
Write-Host ""
Write-Host "Creating DNS security policy: $dnsSecurityPolicyName"
$null = az dns-resolver policy create `
    --resource-group $resourceGroupName `
    --name $dnsSecurityPolicyName `
    --location $location `
    --tags "Purpose=DNS-Security-Lab"

# Get VNet resource ID
$vnetId = az network vnet show --resource-group $resourceGroupName --name $vnetName --query id -o tsv

# Create Virtual Network Link
Write-Host ""
Write-Host "Creating virtual network link: $vnetLinkName"
$vnetConfig = "{'id':'$vnetId'}"
$null = az dns-resolver policy vnet-link create `
    --resource-group $resourceGroupName `
    --policy-name $dnsSecurityPolicyName `
    --name $vnetLinkName `
    --virtual-network $vnetConfig `
    --location $location

# Create DNS Domain List
Write-Host ""
Write-Host "Creating DNS domain list: $domainListName"
$null = az dns-resolver policy dns-domain-list create `
    --resource-group $resourceGroupName `
    --policy-name $dnsSecurityPolicyName `
    --name $domainListName `
    --domains "malicious.contoso.com." "exploit.adatum.com." `
    --location $location

# Get Domain List resource ID
$domainListId = az dns-resolver policy dns-domain-list show `
    --resource-group $resourceGroupName `
    --policy-name $dnsSecurityPolicyName `
    --name $domainListName `
    --query id -o tsv

# Create DNS Security Rule
Write-Host ""
Write-Host "Creating DNS security rule: $securityRuleName"
$actionConfig = "{'actionType':'Block','blockResponseCode':'ServFail'}"
$domainListConfig = "[{'id':'$domainListId'}]"
$null = az dns-resolver policy dns-security-rule create `
    --resource-group $resourceGroupName `
    --policy-name $dnsSecurityPolicyName `
    --name $securityRuleName `
    --priority 100 `
    --action $actionConfig `
    --domain-lists $domainListConfig `
    --rule-state "Enabled" `
    --location $location

# Get Log Analytics Workspace resource ID
Write-Host ""
Write-Host "Getting Log Analytics workspace resource ID..."
$logAnalyticsWorkspaceId = az monitor log-analytics workspace show `
    --resource-group $resourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --query id -o tsv

# Configure diagnostic settings for DNS Security Policy
Write-Host ""
Write-Host "Configuring diagnostic settings for DNS Security Policy..."
$diagnosticLogsConfig = @"
[
    {
        "category": "DnsQueryLogs",
        "enabled": true,
        "retentionPolicy": {
            "enabled": false,
            "days": 0
        }
    }
]
"@

$null = az monitor diagnostic-settings create `
    --resource "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/dnsResolverPolicies/$dnsSecurityPolicyName" `
    --name "dns-policy-diagnostics" `
    --workspace $logAnalyticsWorkspaceId `
    --logs $diagnosticLogsConfig

# Clear the password variable for security
$vmPasswordText = $null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Lab Environment Details:" -ForegroundColor Cyan
Write-Host "------------------------"
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Location: $location"
Write-Host "Virtual Network: $vnetName ($vnetAddressSpace)"
Write-Host "VM Name: $vmName"
Write-Host "VM Username: $vmAdminUsername"
Write-Host "VM Password: [HIDDEN - provided during deployment]"
Write-Host "DNS Security Policy: $dnsSecurityPolicyName"
Write-Host "Domain List: $domainListName"
Write-Host "Blocked Domains: malicious.contoso.com., exploit.adatum.com."
Write-Host "Security Rule: $securityRuleName (Priority: 100, Action: Block)"
Write-Host "Log Analytics Workspace: $logAnalyticsWorkspaceName"
Write-Host ""
Write-Host "VM Access Instructions:" -ForegroundColor Yellow
Write-Host "----------------------"
Write-Host "1. Go to the Azure Portal: https://portal.azure.com"
Write-Host "2. Navigate to Virtual Machines"
Write-Host "3. Select '$vmName' in resource group '$resourceGroupName'"
Write-Host "4. Click 'Serial console' in the left menu under 'Help'"
Write-Host "5. Login with username: $vmAdminUsername"
Write-Host "6. Use the password you provided during deployment"
Write-Host ""
Write-Host "To test DNS blocking from the VM serial console, try:" -ForegroundColor Yellow
Write-Host "nslookup malicious.contoso.com"
Write-Host "nslookup exploit.adatum.com"
Write-Host ""
Write-Host "These queries should fail due to the DNS security policy." -ForegroundColor Green
Write-Host "Test that normal domains work: nslookup google.com"
Write-Host ""
