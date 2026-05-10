
#Requires -Module ucorp.lawfunctions

# Authentication token is generated using the appId and appSecret of an AAD App registration with permissions to read Intune data and write to Log Analytics workspace.
# The script retrieves the list of all Intune managed devices and their hardware information, then uploads this data to a custom table in Log Analytics using the Data Collection Rule.

$TenantId = Get-AutomationVariable -Name "TenantId"

# Get data to generate access token for Graph API resources
$AutomationCredential = Get-AutomationPSCredential -Name "LoggingSP"
$AppId = $AutomationCredential.UserName
$securePassword = $AutomationCredential.Password
$AppSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

# Get data to generate access token for Graph API Intune
$AutomationCredential = Get-AutomationPSCredential -Name "IntuneSP"
$IntuneAppId = $AutomationCredential.UserName
$securePassword = $AutomationCredential.Password
$IntuneAppSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
$Headers = Get-LawAccessToken -AppId $IntuneAppId -AppSecret $IntuneAppSecret -TenantId $TenantId

$TableName = "IntuneHWInfo"
$DcrName = "Dcr" + $TableName

#Main
Write-output "getting list of all Intune Object ID's"
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id"
$Response = (Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get)
$content = $Response.value
$NextLink = $Response."@odata.nextLink"
    while ($null -ne $Nextlink){
        $Response = (Invoke-RestMethod -Uri $NextLink -Headers $Headers -Method Get)
        $NextLink = $Response."@odata.nextLink"
        $Content += $Response.value
    }

Write-Output "Gathered list of $($content.count) objects. Proceeding to retrieve hardware information for each individually..."

$intuneHWInfo = New-Object System.Collections.ArrayList
$content | ForEach-Object {
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices(`'$($_.id)`')?`$select=hardwareinformation"
        $data = (Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get)
        [void]$intuneHWInfo.add($data.hardwareInformation)
    } catch {
        Write-output "Error retrieving hw info for $($_.id)"
    }
}

$DataVariable = $intuneHWInfo

if ($null -eq $DataVariable){
    # Endpoint sends data directly to DCR endpoint, so we need to get the DCR details to get the endpoint and immutable id for the DCR
    $DcrDetails = Get-LawDcrDetails -DcrName $DcrName -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    # Send data to Log Analytics using the DCR
    Set-LawIngestCustomLogDcr -DcrEndpoint $DcrDetails.DcrEndPointUri -DcrImmutableId $DcrDetails.DcrImmutableId `
    -TableName $TableName -DcrStream $DcrDetails.DcrStream -Data $DataVariable -BatchAmount $BatchAmount `
    -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId
}
else {
    Write-output "No data found to upload"
}