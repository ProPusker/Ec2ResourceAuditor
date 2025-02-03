```markdown
# AWS Resource Auditor

A cross-account auditing tool that identifies underutilized EC2 resources across multiple AWS accounts. Generates actionable reports to optimize costs and improve security.

## Features

- 🔍 **Multi-Account Scanning** (Supports AWS Organizations and individual accounts)
- 🌍 **Multi-Region Support** (All commercial regions)
- 📊 **Identifies**:
  - Unattached EBS volumes
  - Stopped EC2 instances
  - Unencrypted EBS volumes
- 📁 **CSV Report Generation** with timestamps
- 🔒 **AWS CLI Profile Integration**
- 🚦 **Error Handling** for permission/access issues


---

## Prerequisites

1. **AWS CLI v2+** ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
2. **PowerShell 5.1+** (Windows) or **PowerShell Core 6+** (Linux/macOS)
3. **AWS IAM Permissions**:
   - `ec2:DescribeInstances`
   - `ec2:DescribeVolumes`
   - `ec2:DescribeRegions`

---

## Installation

1. **Clone Repository**:
   ```powershell
   git clone https://github.com/yourrepo/aws-resource-auditor.git
   cd aws-resource-auditor
   ```

2. **Configure AWS Profiles**:
   ```powershell
   # For each account (repeat for all managed accounts)
   aws configure --profile account1
   aws configure --profile account2
   ```

3. **Verify Setup**:
   ```powershell
   aws sts get-caller-identity --profile account1
   ```

---

## Configuration

### IAM Policy Requirements
Create this policy for audit roles:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeVolumes",
                "ec2:DescribeRegions"
            ],
            "Resource": "*"
        }
    ]
}
```

### Recommended AWS CLI Profile Setup
```
[profile audit-role]
region = us-east-1
role_arn = arn:aws:iam::123456789012:role/AuditRole
source_profile = default
```

---

## Usage

### Basic Scan
```powershell
.\AWS-ResourceAuditor.ps1 -ProfileNames "dev-account", "prod-account"
```

### Custom Regions
```powershell
.\AWS-ResourceAuditor.ps1 -ProfileNames "test-account" -Regions "us-east-1","eu-west-1"
```

### Save Report to Specific Location
```powershell
.\AWS-ResourceAuditor.ps1 -ProfileNames "account1" -ReportPath "C:\audits\$(Get-Date -Format 'yyyy-MM').csv"
```

### Full Parameter List
| Parameter    | Description                          | Default Value                          |
|--------------|--------------------------------------|----------------------------------------|
| ProfileNames | AWS CLI profile names (comma-sep)    | **Required**                           |
| Regions      | Regions to scan (comma-sep)          | All commercial regions                 |
| ReportPath   | Output CSV file path                 | `~/Documents/AWS_Audit_<timestamp>.csv`|

---

## Output

### Sample CSV Report

| Account       | Region    | ResourceType         | ResourceId   | AdditionalInfo                          |
|---------------|-----------|----------------------|--------------|-----------------------------------------|
| prod-account  | us-east-1 | Unattached Volume    | vol-0abc123  | Size: 100GB | Type: gp3 | Encrypted: True |
| dev-account   | eu-west-1 | Stopped Instance     | i-0xyz789    | Type: t3.large | Launched: 2023-07-15 |
| test-account  | ap-south-1 | Unencrypted Volume  | vol-0def456  | Attached to i-04567 | State: in-use |

### Report Fields
1. **Account**: AWS account alias/profile name
2. **Region**: AWS region where resource exists
3. **ResourceType**: One of three audit types
4. **ResourceId**: AWS resource identifier
5. **AdditionalInfo**: Contextual metadata about the resource

---

## Best Practices

1. **Schedule Regular Audits** (Weekly/Monthly)
   ```powershell
   # Windows Task Scheduler example:
   Trigger: Monthly, 1st day at 2:00 AM
   Action: powershell.exe -File C:\scripts\AWS-ResourceAuditor.ps1 -ProfileNames "prod"
   ```

2. **Combine with AWS Organizations**
   ```powershell
   $allAccounts = (aws organizations list-accounts --query 'Accounts[*].Name' --output text)
   .\AWS-ResourceAuditor.ps1 -ProfileNames $allAccounts
   ```

3. **Automate Cleanup** (Example for volumes):
   ```powershell
   Import-Csv $ReportPath | Where-Object { 
     $_.ResourceType -eq "Unattached Volume" -and $_.AdditionalInfo -match "Encrypted: True"
   } | ForEach-Object {
     aws ec2 delete-volume --volume-id $_.ResourceId --region $_.Region --profile $_.Account
   }
   ```

---

## Troubleshooting

### Common Errors

| Error Message | Solution |
|---------------|----------|
| `Unable to locate credentials` | Verify AWS CLI profile configuration |
| `An error occurred (UnauthorizedOperation)` | Update IAM policies for audit role |
| `The security token included in the request is invalid` | Renew AWS session credentials |

### Debug Mode
```powershell
$DebugPreference = 'Continue'
.\AWS-ResourceAuditor.ps1 -ProfileNames "test-account" -Regions "us-east-1"
```

---
