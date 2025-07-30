# Azure DNS Security Policy Lab - File Overview

This document provides a comprehensive overview of all files in the Azure DNS Security Policy Lab, including their purpose, functionality, and relationships.

## 📁 Complete File Structure

```
AzDnsSecurityPolicyLab/
├── README.md                    # Main lab documentation and quick start guide
├── FILE_OVERVIEW.md             # This file - detailed descriptions of all components
├── answers.json                 # User configuration file with Azure settings
├── answers.json.template        # Template for creating answers.json
├── deploy-lab.sh               # Primary deployment script (Bash/Linux)
├── Deploy-Lab.ps1              # Primary deployment script (PowerShell/Windows)
├── remove-lab.sh               # Lab cleanup script (Bash/Linux)
├── Remove-Lab.ps1              # Lab cleanup script (PowerShell/Windows)
├── validate-environment.sh     # Pre-deployment environment validation
├── test-dns-policy.sh          # DNS testing instructions and commands
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
- Virtual network configuration (10.0.0.0/16)
- VM settings (Ubuntu 22.04 LTS, Standard_B1s)
- DNS security policy names and settings
- Log Analytics workspace configuration

**Dependencies**: Used by all deployment and cleanup scripts

**Sample Structure**:
```json
{
  "subscriptionId": "YOUR-SUBSCRIPTION-ID-HERE",
  "resourceGroupName": "rg-dns-security-lab",
  "location": "eastus2",
  "vnetName": "vnet-dns-security-lab",
  "logAnalyticsWorkspaceName": "law-dns-security-lab"
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
- Secure password prompting for VM
- Comprehensive resource creation with error handling
- Log Analytics workspace setup with diagnostic settings
- DNS security policy configuration with specific domains
- Serial console access setup (no public IP)

**Deployment Sequence**:
1. Validates configuration file
2. Authenticates to Azure
3. Creates resource group
4. Creates Log Analytics workspace
5. Sets up virtual network and subnet
6. Creates Network Security Group (internal access only)
7. Deploys Ubuntu VM (no public IP)
8. Creates DNS security policy
9. Creates domain list with malicious domains
10. Creates security rule (priority 100, block action)
11. Links policy to virtual network
12. Configures diagnostic settings for monitoring

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

1. **Resource Group** (`rg-dns-security-lab`)
   - Container for all lab resources
   - Tagged for easy identification

2. **Log Analytics Workspace** (`law-dns-security-lab`)
   - Collects DNS query logs and diagnostic data
   - Enables monitoring and analysis of DNS security events
   - Configured with diagnostic settings integration

3. **Virtual Network** (`vnet-dns-security-lab`)
   - Address space: 10.0.0.0/16
   - Single subnet: 10.0.1.0/24
   - DNS servers: Azure-provided (automatic)

4. **Network Security Group** (`nsg-dns-security-lab`)
   - Internal access rules only
   - No public internet access allowed
   - Optimized for serial console access

5. **Ubuntu Virtual Machine** (`vm-dns-security-lab`)
   - Size: Standard_B1s (cost-effective)
   - OS: Ubuntu 22.04 LTS
   - No public IP address (serial console access only)
   - Password authentication
   - Attached to internal subnet

6. **DNS Security Policy** (`dns-security-policy-lab`)
   - Main policy container
   - Linked to virtual network
   - Configured with diagnostic settings

7. **DNS Domain List** (`domain-list-malicious`)
   - Contains blocked domains:
     - `malicious.contoso.com.`
     - `exploit.adatum.com.`
   - Note: Trailing dots are required for proper DNS matching

8. **DNS Security Rule** (`security-rule-block-malicious`)
   - Priority: 100 (high priority)
   - Action: Block
   - Response: ServFail
   - State: Enabled

9. **Virtual Network Link** (`vnet-link-dns-security`)
   - Links DNS security policy to virtual network
   - Enables automatic DNS filtering

10. **Diagnostic Settings** (`dns-policy-diagnostics`)
    - Captures DNS query logs
    - Sends data to Log Analytics workspace
    - Enables monitoring and alerting

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
- No public IP addresses assigned
- All access via Azure Portal serial console
- Internal network communication only

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

1. **Basic DNS Security**: Understand how DNS policies work
2. **Monitoring and Analysis**: Learn Azure monitoring capabilities  
3. **Policy Management**: Practice security rule configuration
4. **Incident Response**: Analyze DNS security events

### Testing Scenarios

1. **Malicious Domain Testing**: Verify blocking effectiveness
2. **Policy Bypass Testing**: Test rule priorities and exceptions
3. **Performance Testing**: Analyze DNS response times
4. **Monitoring Validation**: Verify log collection and analysis

### Production Preparation

1. **Architecture Planning**: Use as reference for production DNS security
2. **Monitoring Setup**: Implement similar monitoring in production
3. **Policy Development**: Test security rules before production deployment
4. **Team Training**: Hands-on experience with Azure DNS security

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
  "resourceGroupName": "rg-dns-security-lab",
  "location": "eastus2",
  "dnsSecurityPolicyName": "dns-security-policy-lab",
  "logAnalyticsWorkspaceName": "law-dns-security-lab"
}
```

### Important Notes

- **Billing**: Lab creates billable Azure resources
- **Access**: VM access via serial console only
- **Cleanup**: Always run removal script when finished
- **DNS Propagation**: Allow 2-3 minutes for DNS changes
- **Monitoring**: Logs appear in Log Analytics within minutes

This comprehensive file overview should help you understand, maintain, and customize the Azure DNS Security Policy Lab according to your specific learning and testing needs.
