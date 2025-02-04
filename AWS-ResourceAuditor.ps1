# Author: Pusker 
# Email: propuskerworks@gmail.com
# Date: 2024-5-3
# Version: 1.0.0

<#
.SYNOPSIS
    AWS Resource Auditor - Identifies unused EC2 resources across multiple accounts
.DESCRIPTION
    Checks multiple AWS accounts for:
    - Unattached EBS volumes
    - Stopped EC2 instances
    - Unencrypted EBS volumes
.NOTES
    Version: 1.2
    Author: Pusker
    Requires: AWS CLI configured with multiple profiles
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$ProfileNames,
    
    [string[]]$Regions = @("us-east-1","us-west-2","eu-west-1"),
    
    [string]$ReportPath = "$env:USERPROFILE\Documents\AWS_Audit_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

$results = @()

function Get-UnattachedVolumes {
    param($profile, $region)
    $volumes = aws ec2 describe-volumes --profile $profile --region $region `
                --query "Volumes[?State=='available'].{ID:VolumeId,Size:Size,Type:VolumeType,Encrypted:Encrypted}" `
                --output json | ConvertFrom-Json
    foreach ($vol in $volumes) {
        $results += [PSCustomObject]@{
            Account        = $profile
            Region         = $region
            ResourceType   = "Unattached Volume"
            ResourceId     = $vol.ID
            AdditionalInfo = "Size: $($vol.Size)GB | Type: $($vol.Type) | Encrypted: $($vol.Encrypted)"
        }
    }
}

function Get-StoppedInstances {
    param($profile, $region)
    $instances = aws ec2 describe-instances --profile $profile --region $region `
                 --query "Reservations[].Instances[?State.Name=='stopped'].{ID:InstanceId,Type:InstanceType,LaunchTime:LaunchTime}" `
                 --output json | ConvertFrom-Json
    foreach ($inst in $instances) {
        $results += [PSCustomObject]@{
            Account        = $profile
            Region         = $region
            ResourceType   = "Stopped Instance"
            ResourceId     = $inst.ID
            AdditionalInfo = "Type: $($inst.Type) | Launched: $($inst.LaunchTime)"
        }
    }
}

function Get-UnencryptedVolumes {
    param($profile, $region)
    $volumes = aws ec2 describe-volumes --profile $profile --region $region `
              --query "Volumes[?Encrypted==`$false].{ID:VolumeId,State:State,Attachments:Attachments[].InstanceId}" `
              --output json | ConvertFrom-Json
    foreach ($vol in $volumes) {
        $attachmentInfo = if ($vol.Attachments) { "Attached to $($vol.Attachments)" } else { "Unattached" }
        $results += [PSCustomObject]@{
            Account        = $profile
            Region         = $region
            ResourceType   = "Unencrypted Volume"
            ResourceId     = $vol.ID
            AdditionalInfo = "$attachmentInfo | State: $($vol.State)"
        }
    }
}

# Main execution
foreach ($profile in $ProfileNames) {
    Write-Host "Checking account: $profile" -ForegroundColor Cyan
    foreach ($region in $Regions) {
        Write-Host "  Scanning region: $region" -ForegroundColor Yellow
        
        try {
            Get-UnattachedVolumes -profile $profile -region $region
            Get-StoppedInstances -profile $profile -region $region
            Get-UnencryptedVolumes -profile $profile -region $region
        }
        catch {
            Write-Warning "Error in $profile/$region : $_"
        }
    }
}

# Export results
if ($results) {
    $results | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Audit report generated: $ReportPath" -ForegroundColor Green
}
else {
    Write-Host "No unused resources found across specified accounts/regions" -ForegroundColor Yellow
}
