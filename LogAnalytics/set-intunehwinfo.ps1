#Requires -Module ucorp.lawfunctions

# This script is designed to create the DCR structure and custom table for Intune HW Info in Log Analytics, and to set the permissions for the Log Ingest API service principal in the DCR.
# The script will also retrieve the list of all Intune managed devices and their hardware information, then upload only one entry of that data so it can create a custom table with the correct schema in Log Analytics.

param(
    [Parameter(Mandatory = $true)] 
    [string]$SetLogIngestApiAppPermissionsDcrLevel,
    [Parameter(Mandatory=$true)]
    [string]$LogIngestServicePrincipalObjectId, # Object Id of the service principal (not the app) used for Log Ingest API
    [Parameter(Mandatory=$true)]
    [ValidateSet("Merge", "Overwrite", "Migrate")]
    [string]$SchemaMode,
    [Parameter(Mandatory=$true)]
    [string]$publisher,
    [Parameter(Mandatory = $true)] 
    [string]$executionPath,
    [Parameter(Mandatory=$true)]
    [string]$tenantId,
    [Parameter(Mandatory=$true)]
    [string]$appId,
    [Parameter(Mandatory=$true)]
    [string]$appSecret,
    [Parameter(Mandatory=$true)]
    [string]$intuneAppId,
    [Parameter(Mandatory=$true)]
    [string]$intuneAppSecret
)

Write-Host "##[debug] Set-IntuneHWInfo.ps1 has been initiated by [$publisher]."
Write-Host "##[debug] Set-IntuneHWInfo.ps1 SchemaMode: [$SchemaMode] SetLogIngestApiAppPermissionsDcrLevel: [$SetLogIngestApiAppPermissionsDcrLevel]."

#region variables
############################## Variables ############################## 

$TableName = "IntuneHWInfo"
$DcrName = "Dcr" + $TableName
$WorkspaceName = "<WorkspaceName>"
$ResourceGroup = "<ResourceGroup>"
$SubscriptionId = "<SubscriptionId>"
$LogDcrTableCreateFromAnyMachine = $true #Change the variable $LogDcrTableCreateFromAnyMachine to $False, which tells the script to not let changes happen from any machine.
$LogDcrTableCreateFromReferenceMachine = @()   # you will add your machine like @("MyDeviceName")

# Convert $SetLogIngestApiAppPermissionsDcrLevel string to boolean
if ($SetLogIngestApiAppPermissionsDcrLevel -eq "true"){[bool]$SetLogIngestApiAppPermissionsDcrLevel = $true} 
else {[bool]$SetLogIngestApiAppPermissionsDcrLevel = $false}

# Convert $LogIngestServicePrincipalObjectId to $null when string is Emtpy
if ($LogIngestServicePrincipalObjectId -eq "Empty"){$LogIngestServicePrincipalObjectId = $null}
#endregion variables

#region prerequisites
############################## Prerequisites ##############################

$irmSplat = @{
    Uri    = "https://login.microsoftonline.com/$($TenantId)/oauth2/v2.0/token"
    Method = 'Post'
}

# Using Application Authentication Token
$irmSplat['Body'] = @{
    client_id     = $intuneAppId
    client_secret = $intuneAppSecret
    scope         = "https://graph.microsoft.com/.default"
    grant_type    = 'client_credentials'
}

$global:accessToken = Invoke-RestMethod @irmSplat -ErrorAction Stop

$global:authHeader = @{
    Authorization = "Bearer $($global:accessToken.access_token)"
}

# Get credentials for Azure API connection
$Headers = Get-LawAccessToken -AppId $appId -AppSecret $appSecret -TenantId $tenantId

# Get workspace details
$LogWorkspaceUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroup/providers/microsoft.operationalinsights/workspaces/$WorkspaceName`?api-version=2021-06-01"
$LogAnalyticsWorkspaceResourceId = (invoke-restmethod -UseBasicParsing -Uri $LogWorkspaceUrl -Method GET -Headers $Headers).id

#region main
############################## Main ##############################

# Get managed device information used to build custom table
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id&`$top=1"
$intuneIDs = (Invoke-RestMethod -Uri $uri -headers $authHeader -Method GET).value.id

$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($intuneIDs)?`$select=hardwareinformation"
$intuneHWInfo = (Invoke-RestMethod -Uri $uri -headers $authHeader -Method GET).hardwareInformation

# Truncate the value to 60 characters to ensure it is accepted by the Log Ingest API
$intuneHWInfo = $intuneHWInfo | ForEach-Object {
    $newObject = @{}
    foreach ($entry in $_.PSObject.Properties) {
        if ($entry.Name.Length -gt 60){
            Write-Warning "[$($entry.Name)] is longer than 60 characters. This will cause the Log Ingest API to reject the data and disable the DCR until the value is fixed." 

            # Rename the property to the truncated value to ensure it is accepted by the Log Ingest API
            $newObject[$entry.Name.Substring(0, 60)] = $entry.Value

            Write-Warning "Old value: [$($entry.Name)] New value: [$($entry.Name.Substring(0, 60))]"
        }
        else {
            $newObject[$entry.Name] = $entry.Value
        }
    }
    [PSCustomObject]$newObject
}

$DataVariable = $intuneHWInfo

# Check if table exist create DCR and table structure based on the data provided. 
# DCR must be created with Kind = "Direct" to be able to use it for direct Log Ingestion API
# otherwise you need to associate the DCR with an DCE: https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-structure
# Will also update the permissions for the Log Ingest API service principal in the DCR based on the variable $SetLogIngestApiAppPermissionsDcrLevel and $LogIngestServicePrincipalObjectId
# Will truncate the value to 60 characters to ensure it is accepted by the Log Ingest API
Set-LawCheckCreateUpdateTableDcrStructure `
    -LogWorkspaceResourceId $LogAnalyticsWorkspaceResourceId `
    -AppId $appId -AppSecret $appSecret -TenantId $TenantId -Verbose:$Verbose `
    -DcrName $DcrName -DcrResourceGroup $ResourceGroup -TableName $TableName -Data $DataVariable -SchemaMode $SchemaMode `
    -LogIngestServicePrincipalObjectId $LogIngestServicePrincipalObjectId `
    -SetLogIngestApiAppPermissionsDcrLevel $SetLogIngestApiAppPermissionsDcrLevel `
    -LogDcrTableCreateFromAnyMachine $LogDcrTableCreateFromAnyMachine `
    -LogDcrTableCreateFromReferenceMachine $LogDcrTableCreateFromReferenceMachine
#endregion main