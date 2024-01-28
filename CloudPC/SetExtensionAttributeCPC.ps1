#=============================================================================================================================
#
# Script Name:     SetExtensionAttributeCPC.ps1
# Description:     Set the extensionAttribute3 for all Windows 365 Cloud PC's to WelcomeMailSent.
#   
# Notes      :     Needed so they will not receive another mail when SendWelcomeMailCPC.ps1 is triggered.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

. .\GenMSALToken.ps1

# Configure variables
$ExtensionAttributeKey = "extensionAttribute3"
$ExtensionAttributeValue = "WelcomeMailSent"

# Functions
function Update-DeviceExtensionAttribute(){

[cmdletbinding()]

param
(
    $Id,
    $ExtensionAttributeKey,
    $ExtensionAttributeValue
)

$Resource = "devices/$Id"
$GraphApiVersion = "beta"
$json = @"
{
    "extensionAttributes": {
        "$ExtensionAttributeKey": "$ExtensionAttributeValue"
    }
}

"@

    try{
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Patch -Body $json -ContentType "application/json")

    } 
    catch{
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break 
    }
}
# End Functions

# Get all Cloud PC's starts with UCORPC and status provisioned
$CPCDevices = @()
$Uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=startsWith(managedDeviceName,'UCORPC') and status eq 'provisioned'"

$CPCDevicesResponse = (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method Get)
[array]$CPCDevices = $CPCDevicesResponse.value
$CPCDevicesNextLink = $CPCDevicesResponse."@odata.nextLink"
while($null -ne $CPCDevicesNextLink){
    $CPCDevicesResponse = (Invoke-RestMethod -Uri $CPCDevicesNextLink -Headers $authHeader -Method Get)
    $CPCDevicesNextLink = $CPCDevicesResponse."@odata.nextLink"
    [array]$CPCDevices += $CPCDevicesResponse.value
}

# Get all Azure AD objects starts with UCORPC with extensionAttribute3 null
$AADDevices = @()
$Uri = "https://graph.microsoft.com/v1.0/devices?`$filter=startsWith(displayName,'UCORPC') and extensionAttributes/extensionAttribute3 eq null&`$count=true&ConsistencyLevel=eventual"

$AADDevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get)
[array]$AADDevices = $AADDevicesResponse.value
$AADDevicesNextLink = $AADDevicesResponse."@odata.nextLink"
while ($null -ne $AADDevicesNextLink) {
    $AADDevicesResponse = (Invoke-RestMethod -Uri $AADDevicesNextLink -Headers $authHeader -Method Get)
    $AADDevicesNextLink = $AADDevicesResponse."@odata.nextLink"
    [array]$AADDevices += $AADDevicesResponse.value
}

Write-Output "Provisioned Cloud PC's found: $(($CPCDevices | Measure-Object -Property DisplayName).Count)."

$updatedCount = 0

foreach($AADDevice in $AADDevices){
    # Check if Cloud PC is active
    if ($AADDevice.accountEnabled -eq $true){
        
        # Check if Cloud PC exist as virtual endpoint as provisioned device
        $CPCDevice = $CPCDevices | Where-Object {$_.ManagedDeviceName -eq $AADDevice.DisplayName}

        if(-not(!$CPCDevice)){             
            try{
                # Update extensionAttribute3 with CPCWelcomeMailHaveBeenSent
                Update-DeviceExtensionAttribute -Id $AADDevice.id -ExtensionAttributeKey $ExtensionAttributeKey -ExtensionAttributeValue $ExtensionAttributeValue
                Write-Output "$($AADDevice.DisplayName): extensionAttribute3 set to $ExtensionAttributeValue"           
                $updatedCount += 1
            } 
            catch { 
                Write-Warning "$($AADDevice.DisplayName): unable to set extensionAttribute3 to $ExtensionAttributeValue"
            }
        }
    }
}

Write-output "$ExtensionAttributeKey set for $updatedCount Cloud PC's"