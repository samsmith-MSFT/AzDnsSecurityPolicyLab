# Azure DNS Security Policy Lab Removal Script (PowerShell)
# This script removes the entire DNS security policy lab environment

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Red
Write-Host "Azure DNS Security Policy Lab Removal" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red

# Check if answers.json exists
if (-not (Test-Path "answers.json")) {
    Write-Error "Error: answers.json file not found. Please ensure it exists with the lab configuration."
    exit 1
}

# Read configuration from answers.json
try {
    $config = Get-Content "answers.json" | ConvertFrom-Json
} catch {
    Write-Error "Error: Failed to parse answers.json. Please ensure it contains valid JSON."
    exit 1
}

$subscriptionId = $config.subscriptionId
$resourceGroupName = $config.resourceGroupName

# Validate required fields
if ([string]::IsNullOrEmpty($subscriptionId)) {
    Write-Error "Error: subscriptionId is required in answers.json"
    exit 1
}

if ([string]::IsNullOrEmpty($resourceGroupName)) {
    Write-Error "Error: resourceGroupName is required in answers.json"
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

# Check if resource group exists
Write-Host ""
Write-Host "Checking if resource group exists: $resourceGroupName"
try {
    $null = az group show --name $resourceGroupName 2>$null
    Write-Host "Resource group found." -ForegroundColor Yellow
} catch {
    Write-Host "Resource group '$resourceGroupName' does not exist. Nothing to remove." -ForegroundColor Green
    exit 0
}

# List resources before deletion
Write-Host ""
Write-Host "Resources to be deleted:" -ForegroundColor Yellow
Write-Host "------------------------"
az resource list --resource-group $resourceGroupName --output table

if (-not $Force) {
    Write-Host ""
    Write-Host "WARNING: This will permanently delete the following resource group and ALL its contents:" -ForegroundColor Red
    Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Red
    Write-Host "Subscription: $(az account show --query name -o tsv)" -ForegroundColor Red
    Write-Host ""
    
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
    
    if ($confirmation -ne "yes") {
        Write-Host "Deletion cancelled." -ForegroundColor Green
        exit 0
    }
}

# Delete the resource group
Write-Host ""
Write-Host "Deleting resource group: $resourceGroupName" -ForegroundColor Red
Write-Host "This may take several minutes..."

try {
    $null = az group delete --name $resourceGroupName --yes --no-wait
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "REMOVAL INITIATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The resource group '$resourceGroupName' deletion has been initiated."
    Write-Host "This process will continue in the background and may take several minutes to complete."
    Write-Host ""
    Write-Host "You can check the deletion status with:" -ForegroundColor Yellow
    Write-Host "az group show --name '$resourceGroupName'"
    Write-Host ""
    Write-Host "When the resource group no longer exists, the deletion is complete." -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Error "Failed to delete resource group: $_"
    exit 1
}
