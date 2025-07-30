# Azure DNS Security Policy Lab

A complete lab environment for testing and learning Azure DNS Security Policies with comprehensive monitoring capabilities. This lab demonstrates how to deploy and configure DNS security policies to block malicious domains using Azure CLI automation in GitHub Codespaces.

## 🎯 Lab Overview

This lab creates a complete Azure environment with:

- **Virtual Network** with an Ubuntu 22.04 LTS virtual machine (no public IP - serial console access)
- **Azure DNS Security Policy** linked to the virtual network
- **DNS Domain List** with malicious domains (`malicious.contoso.com.`, `exploit.adatum.com.`)
- **DNS Security Rules** to block specific domains with ServFail response
- **Network Security Group** for internal access only
- **Log Analytics Workspace** for DNS query monitoring and diagnostics
- **Diagnostic Settings** configured to capture all DNS security events

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                Resource Group                       │    │
│  │                                                     │    │
│  │  ┌─────────────────┐    ┌─────────────────────────┐  │    │
│  │  │  Virtual Network │    │   DNS Security Policy  │  │    │
│  │  │  (10.0.0.0/16)  │◄───┤  - Domain List         │  │    │
│  │  │                 │    │  - Security Rules       │  │    │
│  │  │  ┌─────────────┐│    │  - VNet Link            │  │    │
│  │  │  │   Subnet    ││    │  - Diagnostic Settings │  │    │
│  │  │  │(10.0.1.0/24)││    └─────────────┬───────────┘  │    │
│  │  │  │             ││                  │              │    │
│  │  │  │  ┌────────┐ ││    ┌─────────────┼───────────┐  │    │
│  │  │  │  │Ubuntu  │ ││    │     NSG     │           │  │    │
│  │  │  │  │VM      │◄┼┼────┤  - Internal │Access     │  │    │
│  │  │  │  └────────┘ ││    │  - No Public│IP         │  │    │
│  │  │  └─────────────┘│    └─────────────┘           │  │    │
│  │  └─────────────────┘                              │  │    │
│  │                     ▲                             │  │    │
│  │            Azure Portal Serial Console            │  │    │
│  │                                                   │  │    │
│  │  ┌─────────────────────────────────────────────────┘  │    │
│  │  │           Log Analytics Workspace                 │    │
│  │  │           - DNS Query Logs                        │    │
│  │  │           - Diagnostic Data                       │    │
│  │  └───────────────────────────────────────────────────┘    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

**✅ NONE!** This lab is designed to run in GitHub Codespaces with no additional setup required.

The Codespaces devcontainer includes:
- Azure CLI (latest version)
- PowerShell 
- jq JSON processor
- All required VS Code extensions

## 🚀 Quick Start

### 1. Open in Codespaces

Click the "Code" button and select "Open with Codespaces" to launch the lab environment.

### 2. Configure Your Subscription

Edit the `answers.json` file and add your Azure subscription ID:

```json
{
  "subscriptionId": "YOUR-SUBSCRIPTION-ID-HERE"
}
```

You can find your subscription ID by running:
```bash
az account list --output table
```

### 3. Deploy the Lab

Run the deployment script:

```bash
./deploy-lab.sh
```

The script will:
- Prompt for Azure authentication via device code
- Request a secure password for the VM
- Deploy all Azure resources
- Configure DNS security policies
- Set up monitoring and diagnostics

### 4. Test DNS Blocking

After deployment, access your VM via the Azure Portal:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to Virtual Machines
3. Select your VM in the resource group
4. Click "Serial console" in the left menu
5. Login with the credentials you provided

Test DNS blocking from the VM:
```bash
nslookup malicious.contoso.com
nslookup exploit.adatum.com
nslookup google.com  # This should work
```

### 5. Monitor DNS Activity

View DNS logs in Log Analytics:
1. Go to your resource group in Azure Portal
2. Open the Log Analytics workspace (`law-dns-security-lab`)
3. Click "Logs" and run KQL queries

### 6. Clean Up

When finished:
```bash
./remove-lab.sh
```

## 📊 DNS Query Monitoring

The lab includes a Log Analytics workspace that automatically collects DNS query logs from the DNS Security Policy. This provides visibility into:

- **All DNS queries** passing through the security policy
- **Blocked queries** and the domains that triggered blocks
- **Query patterns** and frequency analysis
- **Security events** for monitoring malicious activity

### Sample KQL Queries

```kusto
// View all DNS queries from the last hour
DnsQueryLogs
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc

// View blocked DNS queries only
DnsQueryLogs
| where ResponseCode == "ServFail"
| project TimeGenerated, QueryName, ClientIP, ResponseCode
| order by TimeGenerated desc

// Count queries by domain
DnsQueryLogs
| summarize QueryCount = count() by QueryName
| order by QueryCount desc

// Analyze query patterns by hour
DnsQueryLogs
| summarize QueryCount = count() by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

## 🔧 Detailed Configuration

### DNS Security Policy Details

The lab creates a DNS security policy with the following configuration:

- **Policy Name**: `dns-security-policy-lab`
- **Action**: Block
- **Response Code**: ServFail
- **Priority**: 100
- **State**: Enabled
- **Blocked Domains**:
  - `malicious.contoso.com.` (note the trailing dot)
  - `exploit.adatum.com.` (note the trailing dot)

### Network Configuration

- **Virtual Network**: `vnet-dns-security-lab` (10.0.0.0/16)
- **Subnet**: `subnet-internal` (10.0.1.0/24)
- **VM**: Ubuntu 22.04 LTS, Standard_B1s
- **Access**: Serial console only (no public IP)

### Monitoring Configuration

- **Log Analytics Workspace**: `law-dns-security-lab`
- **Diagnostic Settings**: Configured to capture DNS query logs
- **Data Retention**: Default Log Analytics retention policy

## 📊 Lab Scenarios

### Scenario 1: Basic DNS Blocking Test

1. Deploy the lab environment
2. Connect to VM via serial console
3. Verify DNS queries are blocked for malicious domains
4. Test legitimate domains work normally

### Scenario 2: DNS Policy Modification

1. Add new domains to the block list
2. Create additional security rules
3. Test different response codes
4. Modify rule priorities

### Scenario 3: Monitoring and Analysis

1. **Log Analytics Integration**: The lab automatically configures diagnostic settings to send DNS query logs to Log Analytics
2. **Monitor DNS Queries**: View all DNS queries and blocked attempts in the Log Analytics workspace
3. **Analyze Security Events**: Use KQL queries to analyze blocked vs. allowed queries
4. **Set Up Alerts**: Configure Azure Monitor alerts for suspicious DNS activity patterns

## 🛠️ Alternative Scripts

### PowerShell Support

For users who prefer PowerShell:

```powershell
# Deploy with what-if check
.\Deploy-Lab.ps1 -WhatIf

# Deploy the lab
.\Deploy-Lab.ps1

# Remove the lab
.\Remove-Lab.ps1
```

### Environment Validation

Before deployment, you can validate your environment:

```bash
./validate-environment.sh
```

This checks for:
- Azure CLI installation and authentication
- Required tools (jq, etc.)
- Subscription access permissions

## 🗂️ File Structure

```
AzDnsSecurityPolicyLab/
├── README.md                    # This documentation
├── FILE_OVERVIEW.md             # Detailed file descriptions
├── answers.json                 # Configuration file (update with your subscription)
├── answers.json.template        # Template for configuration
├── deploy-lab.sh               # Main deployment script (Bash)
├── Deploy-Lab.ps1              # Main deployment script (PowerShell)
├── remove-lab.sh               # Lab cleanup script (Bash)
├── Remove-Lab.ps1              # Lab cleanup script (PowerShell)
├── validate-environment.sh     # Pre-deployment validation
├── test-dns-policy.sh          # DNS testing instructions
└── .devcontainer/              # GitHub Codespaces configuration
    └── devcontainer.json       # Container setup and tools
```

## 🔒 Security Features

### No Public Network Access
- VM has no public IP address
- Access only via Azure Portal serial console
- Network Security Group allows internal traffic only
- No SSH keys or direct network access required

### DNS Security Policy
- Blocks malicious domains at the DNS level
- Returns ServFail response for blocked queries
- Linked to virtual network for automatic protection
- Configurable priority and response types

### Monitoring and Auditing
- All DNS queries logged to Log Analytics
- Blocked attempts tracked and analyzed
- KQL queries for security analysis
- Integration with Azure Monitor for alerts

## ❓ Troubleshooting

### Common Issues

**"No subscription found"**
- Ensure you've updated `answers.json` with your subscription ID
- Run `az account list` to verify your subscriptions

**"VM password requirements"**
- Password must be 12-123 characters
- Must contain uppercase, lowercase, numbers, and special characters

**"DNS queries not being blocked"**
- Wait 2-3 minutes after deployment for DNS propagation
- Ensure domains have trailing dots (malicious.contoso.com.)
- Check VM is using Azure DNS (should be automatic)

**"Cannot access VM"**
- Use Azure Portal serial console only
- VM has no public IP by design
- Login with username/password provided during deployment

### Getting Help

1. Check the [FILE_OVERVIEW.md](FILE_OVERVIEW.md) for detailed file descriptions
2. Review deployment logs for specific error messages
3. Ensure all prerequisites are met in your Azure subscription
4. Use the validation script to check your environment

## 📚 Learning Resources

- [Azure DNS Security Policies Documentation](https://docs.microsoft.com/en-us/azure/dns/dns-security-policy-overview)
- [Azure DNS Resolver Documentation](https://docs.microsoft.com/en-us/azure/dns/dns-resolver-overview)
- [Azure Monitor and Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [KQL Query Language Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)

## 🤝 Contributing

This lab is designed for educational purposes. Feel free to modify the scripts and configuration to suit your learning needs. Key areas for customization:

- Add additional blocked domains
- Modify network topology
- Extend monitoring capabilities
- Add automated testing scenarios

---

**⚠️ Important Notes:**
- This lab creates billable Azure resources
- Remember to clean up resources when done (`./remove-lab.sh`)
- VM access is via serial console only - no SSH/RDP
- DNS changes may take 2-3 minutes to propagate
