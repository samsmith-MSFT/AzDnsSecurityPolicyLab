# Azure DNS Private Resolver Lab - File Overview

This document provides a comprehensive overview of all files in the Azure DNS Private Resolver Lab, including their purpose, functionality, and relationships.

## 📁 Complete File Structure

```
AzDnsSecurityPolicyLab/
├── README.md                    # Main lab documentation and quick start guide
├── FILE_OVERVIEW.md             # This file - detailed descriptions of all components
├── answers.json                 # User configuration file with Azure settings
├── answers.json.template        # Template for creating answers.json
├── deploy-lab.sh               # Primary deployment script (Private Resolver + On-Prem + DNS Security Policy)
├── Deploy-Lab.ps1              # Primary deployment script (PowerShell/Windows) - placeholder
├── remove-lab.sh               # Lab cleanup script (Bash/Linux)
├── Remove-Lab.ps1              # Lab cleanup script (PowerShell/Windows) - placeholder
├── validate-environment.sh     # Pre-deployment environment validation
├── test-dns-policy.sh          # Testing instructions for all demos (resolver + security policy)
└── .devcontainer/              # GitHub Codespaces configuration
    └── devcontainer.json       # Container setup, tools, and extensions
```

## 📋 Configuration Files

### `answers.json` 
**Purpose**: Primary configuration file containing all deployment parameters

**Required User Input**:
- `subscriptionId`: Your Azure subscription ID (MUST be updated)

**Pre-configured Settings**:
- Resource group name and location (East US 2)
- Hub virtual network configuration (10.0.0.0/16)
- On-prem virtual network configuration (10.1.0.0/16)
- VM settings (Ubuntu 22.04 LTS, Windows Server 2022)
- DNS security policy names and settings
- Private Resolver configuration
- Private endpoint and private DNS zone settings
- Log Analytics workspace configuration

**Dependencies**: Used by all deployment and cleanup scripts

**Sample Structure**:
```json
{
  "subscriptionId": "YOUR-SUBSCRIPTION-ID-HERE",
  "resourceGroupName": "rg-dns-resolver-lab",
  "location": "eastus2",
  "vnetName": "vnet-dns-lab",
  "logAnalyticsWorkspaceName": "law-dns-resolver-lab"
}
```

### `answers.json.template`
**Purpose**: Template file showing the required structure and all available configuration options

**Usage**: Copy to `answers.json` and customize for your environment

**Benefits**: 
- Shows all configurable parameters
- Includes comments and examples
- Helps prevent configuration errors

## 🚀 Deployment Scripts

### Bash Scripts (Linux/macOS/WSL/Codespaces)

#### `deploy-lab.sh`
**Purpose**: Complete lab deployment automation using Azure CLI

**Key Features**:
- Device code authentication (perfect for Codespaces)
- Secure password prompting for all VMs (shared password)
- Comprehensive resource creation with error handling
- Private Resolver with inbound and outbound endpoints
- DNS forwarding ruleset with configurable on-prem domain
- Simulated on-prem environment with Windows DNS Server and Ubuntu client
- Storage account with private endpoint and private DNS zone
- VNet peering between hub and on-prem networks
- DNS security policy configuration with domain blocking
- Log Analytics workspace setup with diagnostic settings
- Serial console access setup (no public IPs)

**Deployment Sequence**:
1. Validates configuration file
2. Authenticates to Azure
3. Creates resource group
4. Creates Log Analytics workspace
5. Sets up hub virtual network and VM subnet
6. Creates Network Security Group (internal access only)
7. Deploys Hub Ubuntu VM (no public IP)
8. Creates resolver inbound subnet (delegated), outbound subnet (delegated), and PE subnet
9. Creates DNS Private Resolver with inbound and outbound endpoints
10. Creates DNS forwarding ruleset with on-prem domain rule
11. Links forwarding ruleset to hub VNet
12. Creates storage account with public access disabled
13. Creates private endpoint for blob storage
14. Creates private DNS zone and links to hub VNet
15. Creates DNS zone group for automatic A record registration
16. Creates on-prem VNet with subnet
17. Creates on-prem NSG and associates with subnet
18. Creates bidirectional VNet peering (hub ↔ on-prem)
19. Sets on-prem VNet custom DNS servers
20. Deploys Windows DNS Server VM (static IP 10.1.1.4)
21. Installs DNS Server role, configures conditional forwarder and on-prem DNS zone via run-command
22. Deploys on-prem client VM and configures DNS to use Windows DNS Server
23. Creates DNS security policy, domain list, security rule
24. Links policy to hub virtual network
25. Configures diagnostic settings for monitoring

**Output**: Complete deployment summary with access instructions

#### `remove-lab.sh`
**Purpose**: Safe and complete lab cleanup

**Features**:
- User confirmation prompts
- Complete resource group deletion
- Efficient cleanup with --no-wait option
- Error handling and status reporting

**Safety Measures**:
- Lists resources before deletion
- Requires user confirmation
- Provides deletion status updates

#### `validate-environment.sh`
**Purpose**: Pre-deployment environment validation

**Checks**:
- Azure CLI installation and version
- Authentication status
- Required tools (jq for JSON processing)
- Subscription access and permissions
- Configuration file validity

**Optimized for Codespaces**: Automatically handles Codespaces-specific environment setup

#### `test-dns-policy.sh`
**Purpose**: Provides testing instructions and sample commands

**Content**:
- Step-by-step testing procedures
- Serial console access instructions
- DNS lookup commands for testing
- Expected results and troubleshooting

### PowerShell Scripts (Windows/Cross-platform)

#### `Deploy-Lab.ps1`
**Purpose**: PowerShell equivalent of the bash deployment script

**Unique Features**:
- `-WhatIf` parameter for dry-run testing
- Windows-native PowerShell experience
- Identical functionality to bash version
- JSON handling optimized for PowerShell

**Cross-platform Compatibility**: Works on Windows, Linux, and macOS with PowerShell Core

#### `Remove-Lab.ps1`
**Purpose**: PowerShell cleanup script

**Features**:
- `-Force` parameter to skip confirmations
- PowerShell-native resource management
- Same safety features as bash version

## 🏗️ Infrastructure Architecture

### Azure Resources Created

The lab deployment creates the following Azure resources:

**Core Resources:**

1. **Resource Group** (`rg-dns-resolver-lab`)
   - Container for all lab resources
   - Tagged for easy identification

2. **Log Analytics Workspace** (`law-dns-resolver-lab`)
   - Collects DNS query logs and diagnostic data
   - Enables monitoring and analysis of DNS resolver and security events

3. **Hub Virtual Network** (`vnet-dns-lab`)
   - Address space: 10.0.0.0/16
   - Subnets:
     - `subnet-vm` (10.0.1.0/24) — Hub Ubuntu VM
     - `subnet-resolver-inbound` (10.0.2.0/28) — Private Resolver inbound endpoint (delegated)
     - `subnet-pe` (10.0.3.0/24) — Private endpoint
     - `subnet-resolver-outbound` (10.0.4.0/28) — Private Resolver outbound endpoint (delegated)

4. **Hub Network Security Group** (`nsg-vm-lab`)
   - Internal access rules only
   - Associated with subnet-vm

5. **Hub Ubuntu Virtual Machine** (`vm-ubuntu-lab`)
   - Size: Standard_B1s
   - OS: Ubuntu 22.04 LTS
   - No public IP (serial console access only)
   - Used for testing outbound DNS forwarding and DNS security policy

**Private Resolver Resources:**

6. **DNS Private Resolver** (`dns-resolver-lab`)
   - Located in hub VNet
   - Inbound Endpoint (`inbound-endpoint`): Dynamically assigned IP in 10.0.2.0/28 subnet
   - Outbound Endpoint (`outbound-endpoint`): Dynamically assigned IP in 10.0.4.0/28 subnet
   - Inbound receives forwarded queries from on-prem Windows DNS Server
   - Outbound forwards queries to on-prem DNS via forwarding ruleset

7. **DNS Forwarding Ruleset** (`dns-forwarding-ruleset-lab`)
   - Linked to hub VNet
   - Contains forwarding rule for configurable on-prem domain → on-prem DNS server (10.1.1.4)

8. **Storage Account** (`stpvtlink<timestamp>`)
   - Public network access disabled
   - Used for private endpoint demo

9. **Private Endpoint** (`pe-storage-lab`)
   - Located in subnet-pe (10.0.3.0/24)
   - Targets storage account blob sub-resource
   - DNS zone group auto-registers A record

10. **Private DNS Zone** (`privatelink.blob.core.windows.net`)
    - Linked to hub VNet (`pdz-link-hub`)
    - Contains A record for storage account → private IP

**On-Prem (Simulated) Resources:**

11. **On-Prem Virtual Network** (`vnet-onprem-lab`)
    - Address space: 10.1.0.0/16
    - Subnet: `subnet-onprem` (10.1.1.0/24)
    - Custom DNS servers: 10.1.1.4

12. **On-Prem Network Security Group** (`nsg-onprem-lab`)
    - Internal access rules
    - Associated with subnet-onprem

13. **VNet Peering** (bidirectional)
    - `hub-to-onprem`: hub VNet → on-prem VNet
    - `onprem-to-hub`: on-prem VNet → hub VNet
    - Forwarded traffic allowed

14. **Windows DNS Server VM** (`vm-dns-server`)
    - Size: Standard_B2s
    - OS: Windows Server 2022 Datacenter
    - Static IP: 10.1.1.4
    - DNS Server role installed with conditional forwarder for `blob.core.windows.net` → Resolver inbound IP
    - Hosts configurable on-prem DNS zone with A record
    - Access via SAC serial console

15. **On-Prem Client VM** (`vm-onprem-client`)
    - Size: Standard_B1s
    - OS: Ubuntu 22.04 LTS
    - DNS configured to use 10.1.1.4 (Windows DNS Server)
    - Used for testing private endpoint resolution

**DNS Security Policy Resources (Add-on):**

16. **DNS Security Policy** (`dns-security-policy-lab`)
    - Domain List (`malicious-domains-list`): `malicious.contoso.com.`, `exploit.adatum.com.`
    - Security Rule (`block-malicious-rule`): Priority 100, Block action
    - VNet Link (`vnet-link-lab`): Links policy to hub VNet
    - Diagnostic Settings: DNS query logs → Log Analytics

17. **Boot Diagnostics** (Managed)
    - Azure-managed boot diagnostics for all VMs

## 🔧 DevContainer Configuration

### `.devcontainer/devcontainer.json`
**Purpose**: GitHub Codespaces environment configuration

**Pre-installed Tools**:
- Azure CLI (latest version)
- PowerShell Core
- jq (JSON processor)
- Git and common development tools

**VS Code Extensions**:
- Azure Account
- Azure Resources
- PowerShell
- JSON support
- Markdown support

**Environment Setup**:
- Automatic script execution permissions
- PATH configuration
- Container lifecycle hooks

**Optimization Features**:
- Fast container startup
- Persistent terminal sessions
- Integrated authentication

## 📊 Monitoring and Diagnostics

### Log Analytics Integration

**DNS Query Logs**: The lab automatically configures diagnostic settings to capture:
- All DNS queries processed by the security policy
- Blocked query attempts and reasons
- Query source information (client IP, timestamp)
- Response codes and processing details

**Data Categories**:
- `DnsQueryLogs`: Complete DNS query information
- Blocked vs. allowed query statistics
- Policy enforcement events
- Performance metrics

**Sample Data Fields**:
```
TimeGenerated    # Timestamp of the query
QueryName        # Domain being queried
ClientIP         # Source IP address
ResponseCode     # DNS response (ServFail for blocked)
PolicyName       # Applied security policy
RuleName         # Triggered security rule
```

### Monitoring Capabilities

**Real-time Analysis**: 
- Live query monitoring through Log Analytics
- KQL-based analysis and reporting
- Custom dashboard creation

**Alerting Integration**:
- Azure Monitor alert rules
- Threshold-based notifications
- Custom alert conditions

**Reporting Features**:
- Query pattern analysis
- Security event summaries
- Blocked domain statistics
- Time-based trend analysis

## 🔒 Security Architecture

### Network Security Model

**Zero Public Access**: 
- No public IP addresses on any VM
- All access via Azure Portal serial console
- Windows VMs use SAC console (type `cmd`, `ch -si 1`)
- Internal network communication only
- VNet peering for cross-network connectivity

**DNS Security**:
- Policy-based domain blocking
- Real-time threat protection
- Configurable response actions
- Audit trail for all DNS queries

**Access Control**:
- Azure RBAC for resource management
- VM-level authentication required
- Secure credential handling

### Compliance Features

**Audit Logging**: Complete DNS query history in Log Analytics
**Data Retention**: Configurable retention policies
**Monitoring**: Real-time security event tracking
**Alerting**: Automated threat notification capabilities

## 🛠️ Customization Options

### Easy Modifications

**Domain Lists**: 
- Add/remove blocked domains in domain list creation section
- Modify domain categories and classifications

**Network Configuration**:
- Adjust IP address ranges in answers.json
- Modify subnet configurations
- Add additional subnets or network segments

**Security Rules**:
- Change response codes (ServFail, NxDomain, etc.)
- Modify rule priorities
- Add multiple security rules with different actions

**Monitoring**:
- Extend diagnostic categories
- Add custom KQL queries
- Configure additional alerting rules

### Advanced Customizations

**Multi-VM Scenarios**: Extend scripts to deploy multiple test VMs
**Custom Policies**: Create additional DNS security policies
**Integration Testing**: Add automated testing scenarios
**Monitoring Extensions**: Custom metrics and dashboards

## 📚 Usage Patterns

### Learning Scenarios

1. **Private Resolver**: Learn how on-prem DNS forwards to Azure Private Resolver
2. **Private Endpoints**: Understand private endpoint DNS resolution chain
3. **Outbound DNS Forwarding**: Learn how Azure VMs resolve on-prem domains via forwarding ruleset
4. **DNS Security**: Understand how DNS policies block malicious domains
5. **Monitoring and Analysis**: Learn Azure monitoring capabilities  
6. **Policy Management**: Practice security rule configuration
7. **Incident Response**: Analyze DNS security events

### Testing Scenarios

1. **Private Endpoint Resolution**: Verify on-prem client resolves storage to private IP
2. **DNS Forwarding Chain**: Trace resolution through Windows DNS → Private Resolver → Private DNS Zone
3. **Outbound Forwarding**: Verify hub VM resolves on-prem domains via outbound endpoint
4. **Malicious Domain Testing**: Verify blocking effectiveness from hub VM
5. **Policy Bypass Testing**: Test rule priorities and exceptions
6. **Performance Testing**: Analyze DNS response times
7. **Monitoring Validation**: Verify log collection and analysis

### Production Preparation

1. **Architecture Planning**: Use as reference for production DNS Private Resolver design
2. **Monitoring Setup**: Implement similar monitoring in production
3. **Policy Development**: Test security rules before production deployment
4. **Team Training**: Hands-on experience with Azure DNS Private Resolver and security

## 🔄 Maintenance and Updates

### Regular Maintenance

**Configuration Updates**: Keep answers.json current with environment changes
**Script Updates**: Maintain compatibility with latest Azure CLI versions
**Documentation**: Update README and FILE_OVERVIEW as needed

### Version Control

**Configuration Management**: Track changes to answers.json
**Script Versioning**: Maintain deployment script history
**Documentation Updates**: Keep all documentation synchronized

### Testing and Validation

**Pre-deployment Testing**: Always run validate-environment.sh
**Post-deployment Verification**: Use test-dns-policy.sh
**Cleanup Verification**: Confirm complete resource removal

---

## 📖 Quick Reference

### Essential Commands

```bash
# Deploy the lab
./deploy-lab.sh

# Validate environment
./validate-environment.sh

# Get testing instructions
./test-dns-policy.sh

# Clean up resources
./remove-lab.sh
```

### PowerShell Equivalents

```powershell
# Deploy with validation
.\Deploy-Lab.ps1 -WhatIf
.\Deploy-Lab.ps1

# Clean up
.\Remove-Lab.ps1
```

### Key Configuration

```json
{
  "subscriptionId": "REQUIRED-UPDATE-THIS",
  "resourceGroupName": "rg-dns-resolver-lab",
  "location": "eastus2",
  "dnsSecurityPolicyName": "dns-security-policy-lab",
  "logAnalyticsWorkspaceName": "law-dns-resolver-lab"
}
```

### Important Notes

- **Billing**: Lab creates billable Azure resources
- **Access**: VM access via serial console only
- **Cleanup**: Always run removal script when finished
- **DNS Propagation**: Allow 2-3 minutes for DNS changes
- **Monitoring**: Logs appear in Log Analytics within minutes

This comprehensive file overview should help you understand, maintain, and customize the Azure DNS Private Resolver Lab according to your specific learning and testing needs.
