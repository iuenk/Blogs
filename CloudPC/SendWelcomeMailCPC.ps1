#=============================================================================================================================
#
# Script Name:     SendWelcomeMailCPC.ps1
# Description:     Send welcome mail to Windows 365 Cloud PC owner when it's done provisioning.
#   
# Notes      :     Send welcome mail to Windows 365 Cloud PC owner and set extensionAttribute3 to WelcomeMailSent.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

. .\GenMSALToken.ps1
. .\GenMail.ps1

# Configure variables
$MailSender = Get-AutomationVariable -Name "MailSender"
$ExtensionAttributeKey = "extensionAttribute3"
$ExtensionAttributeValue = "WelcomeMailSent"

# Functions
function Get-CPCUser(){

[cmdletbinding()]

param
(
    $userPrincipalName
)

    try{
        $Resource = "users/$userPrincipalName"
        $Uri = "https://graph.microsoft.com/v1.0/$($Resource)" 
        (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method Get)

    }
    catch{
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Output "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        throw "Get-CPCUser error"
    }
}

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

# Mail style
$css = "<html>
<head>
<style>
table, th, td {
  border: 0;
  width: 580px;
}
th, td {
  padding: 5px;
}
th {
  text-align: left;
  font-family: Arial, Helvetica, Helvetica Neue, sans-serif;
  font-size: 18px;
  color: #ff6200;
}
td {
  text-align: left;
  font-family: Arial, Helvetica, Helvetica Neue, sans-serif;
  font-size: 11pt;
  color: #333333;
}
</style>
</head>"

# Mail body
$body = "<body>
<center>
<table>
<tr><th>Attention: Your vCMW is ready!</th></tr>
<tr><td>Dear USER_GIVENNAME,</td></tr>
<tr><td>Please make sure to sign-in today, so your device CPC_NAME can finalize the setup and will be ready when you need it.</td></tr>
<tr><td>To <a href=START_URL>get started</a> with your virtual Cloud Managed Workplace, go to the <a href=W365_URL>Windows 365 Portal</a>. Download the Remote Desktop Client (recommended) or start your device directly from the portal.</td></tr>
<tr><td>Go the <a href=FAQ_URL>Frequently Asked Questions</a> or contact the IT Service Desk in case of any technical issues.</td></tr>
</table>
</center>
</body></html>"

$mailTemplate = $css + $body
$Subject = "Your Virtual Cloud Managed Workplace (vCMW) is ready!"

$FAQ = "https://ingglits.service-now.com/wps?id=kb_article_view&sys_kb_id=f61257fa877a1910a607a6c83cbb35dc"
$START = "https://ingglits.service-now.com/wps?id=kb_article_view&sysparm_article=KB0015835"
$W365 = "https://windows365.microsoft.com"

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
while($null -ne $AADDevicesNextLink) {
    $AADDevicesResponse = (Invoke-RestMethod -Uri $AADDevicesNextLink -Headers $authHeader -Method Get)
    $AADDevicesNextLink = $AADDevicesResponse."@odata.nextLink"
    [array]$AADDevices += $AADDevicesResponse.value
}

# To be sure to get only Cloud PC's that are provisioned starts with UCORPC and have extensionAttribute3 null
Write-Output "new Cloud PC's found: $(($AADDevices | Where-Object {$_.displayName -in $CPCDevices.ManagedDeviceName} | Measure-Object -Property DisplayName).Count)"

$updatedCount = 0

foreach($AADDevice in $AADDevices){
    # Check if Cloud PC is active
    if($AADDevice.accountEnabled -eq $true){
        
        # Check if Cloud PC exist as virtual endpoint as provisioned device
        $CPCDevice = $CPCDevices | Where-Object {$_.ManagedDeviceName -eq $AADDevice.DisplayName}

        if(-not(!$CPCDevice)){
            # Gathering user information    
            try{
                Write-Output "$($AADDevice.DisplayName): Primary user is $($CPCDevice.userPrincipalName)"                           
                
                $UserInfo = Get-CPCUser -userPrincipalName $CPCDevice.userPrincipalName
                Write-Output "$($UserInfo.UserPrincipalName): Primary SMTP for user is $($UserInfo.mail)"
            }
            catch{
                Write-Warning "Unable to find primary SMTP for user $($UserInfo.UserPrincipalName)"
                Write-Warning $_.Exception.Message
                Write-Output ""
                break
            }            
                
            try{
                # Update extensionAttribute3 with CPCWelcomeMailHaveBeenSent
                Update-DeviceExtensionAttribute -Id $AADDevice.id -ExtensionAttributeKey $ExtensionAttributeKey -ExtensionAttributeValue $ExtensionAttributeValue
                Write-Output "$($AADDevice.DisplayName): extensionAttribute3 set to $ExtensionAttributeValue"
                $updatedCount += 1

                try{
                    # Send mail here
                    $bodyTemplate = $mailTemplate
                    $bodyTemplate = $bodyTemplate.Replace('FAQ_URL', $FAQ)
                    $bodyTemplate = $bodyTemplate.Replace('START_URL', $START)
                    $bodyTemplate = $bodyTemplate.Replace('W365_URL', $W365)
                    $bodyTemplate = $bodyTemplate.Replace('CPC_NAME', $($AADDevice.DisplayName))
                    $bodyTemplate = $bodyTemplate.Replace('USER_GIVENNAME', $($UserInfo.givenName))

                    $Recipients = @(
                        $($CPCDevice.userPrincipalName)
                    )

                    Send-Mail -Recipients $Recipients -Subject $Subject -Body $bodyTemplate -MailSender $MailSender
                    Write-Output "$($AADDevice.DisplayName): Send welcome mail to $($UserInfo.UserPrincipalName)"
                }
                catch{
                    Write-Warning "$($AADDevice.DisplayName): Unable to send welcome mail to $($UserInfo.mail)"    
                }   
            } 
            catch{ 
                Write-Warning "$($AADDevice.DisplayName): unable to set $ExtensionAttributeValue"
            }
        }
    }
    else{
        Write-Output "$($AADDevice.DisplayName): device object account is not enabled"
    }
}

Write-output "$ExtensionAttributeKey set for $updatedCount Cloud PC's"