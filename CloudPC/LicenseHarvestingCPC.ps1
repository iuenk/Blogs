#=============================================================================================================================
#
# Script Name:     LicenseHarvestingCPC.ps1
# Description:     When Windows 365 Cloud PC is not used in the last 45 days the owner's license will be revoked.
#   
# Notes      :     Revoke owner's license and also check if provisioning group can be removed. Users member of the VIP group
#                  are not in scope. A report of all harvesting devices will be uploaded to SharePoint.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

. .\GenMSALToken.ps1

#Configure variables
$Path = "$env:TEMP"
$harvestedDevicesFileName = "harvestedDevices" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".csv"
$harvestedDevicesCSV = "$Path\$harvestedDevicesFileName"
$LogFileName = "licenseHarvesting" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".log"
$LogFile = "$Path\$LogFileName"
$inactiveMinimumInDays = 20
$inactiveThresholdInDays = 45
$noRevokeGroup = "SG_CPC_NoRevoke"
$Server = "ucorp.local"
$ExtensionAttributeKey = "extensionAttribute2"
$UPN = Get-AutomationVariable -Name "UPN"
$currentTime = ([System.DateTimeOffset]::Now).DateTime

$SiteURL = Get-AutomationVariable -Name "siteurl"
$ShortSiteURL = "/" + $SiteURL.split("/",4)[-1]
$ReportFolder = Get-AutomationVariable -Name "reportFolder"
$DestinationPath = $ShortSiteURL + $ReportFolder + "/CPC_LicenseHarvesting"

# Credentials
Try {
    $automationCredential = Get-AutomationPSCredential -Name "CpcCreds"
    $userName = $AutomationCredential.UserName  
    $securePassword = $AutomationCredential.Password
    $psCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $securePassword 

    # Connect to Microsoft services
    Connect-PnPOnline -Url $SiteURL -Credentials $psCredential
} 
Catch {
    Write-output "Cannot connect to Microsoft services"
    break
}

# Functions
function Get-ManagedDevice(){

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)] $id
)

$Resource = "deviceManagement/managedDevices"
$graphApiVersion = "beta"

$attempt = 0
    do {
        try {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id"
            Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get

            if (-not $LASTEXITCODE){
                $success = $true
            } else {
                throw "Transient error. LASTEXITCODE is $LASTEXITCODE."
            }
        }
        catch { 
            if ($attempt -eq 2){
                Write-Error "Task failed. With all $attempt attempts. Error: $($Error[0])"
                throw
            }
            Write-Host "Task failed. Attempt $attempt. Will retry in next $(2 * $attempt) seconds. Error: $($Error[0])"
            Start-Sleep -Seconds $(2 * $attempt)
        }
        $attempt++
    } until($success)
}

function Get-AADDevice(){

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)] $displayName
)

$Resource = "devices"
$graphApiVersion = "v1.0"

    try {
        $Uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$displayName'&`$count=true&ConsistencyLevel=eventual"
        (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value

    } 
    catch {
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

function Get-CPCProvisioningPolicy(){

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)] $id
)

$Resource = "deviceManagement/virtualEndpoint/provisioningPolicies/$id"
$graphApiVersion = "beta"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=Assignments"
        Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
    }
    catch { 
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

function Get-AllUserCPCDevices(){

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)] $userPrincipalName
)

$Resource = "deviceManagement/virtualEndpoint/cloudPCs"
$graphApiVersion = "beta"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/?`$filter=userPrincipalName eq '$userPrincipalName'&`$count=true&ConsistencyLevel=eventual"
        (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).Value
    }
    catch { 
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

function Get-CPCDeviceRemoteConnectionStatus(){

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)] $id
)

$Resource = "deviceManagement/virtualEndpoint/reports"
$graphApiVersion = "beta"

$attempt = 0
    do {
        try {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/getRealTimeRemoteConnectionStatus(cloudPcId='$id')"
            (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).Values

            if (-not $LASTEXITCODE){
                $success = $true
            } else {
                throw "Transient error. LASTEXITCODE is $LASTEXITCODE."
            }
        }
        catch { 
            if ($attempt -eq 2){
                Write-Error "Task failed. With all $attempt attempts. Error: $($Error[0])"
                throw
            }
            Write-Host "Task failed. Attempt $attempt. Will retry in next $(2 * $attempt) seconds. Error: $($Error[0])"
            Start-Sleep -Seconds $(2 * $attempt)
        }
        $attempt++
    } until($success)
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

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Patch -Body $json -ContentType "application/json")

    } 
    catch {
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

function Measure-Latest {
    BEGIN {$latest = $null}
    PROCESS {
            if (($_ -ne $null) -and (($null -eq $latest) -or ($_ -gt $latest))){
                $latest = $_ 
            }
    }
    END {$latest}
}

function Write-Log{
	param (
        [Parameter(Mandatory=$True)]
        [array]$LogOutput,
        [Parameter(Mandatory=$True)]
        [string]$Path
	)
	    $currentDate = (Get-Date -UFormat "%d-%m-%Y")
	    $currentTime = (Get-Date -UFormat "%T")
	    $logOutput = $logOutput -join (" ")
	    "[$currentDate $currentTime] $logOutput" | Out-File $Path -Append
}
# End Functions

# Remove previous files if not cleanup up properly
Get-ChildItem -Path $Path | Where-Object {$_.Name -like "harvestedDevices*"} | Remove-Item
Get-ChildItem -Path $Path | Where-Object {$_.Name -like "licenseHarvesting*"} | Remove-Item

# Get all Cloud PC's
$CPCDevices = @()
$Uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=status eq 'provisioned'"

$CPCDevicesResponse = (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method Get)
[array]$CPCDevices = $CPCDevicesResponse.value
$CPCDevicesNextLink = $CPCDevicesResponse."@odata.nextLink"
while ($null -ne $CPCDevicesNextLink) {
    $CPCDevicesResponse = (Invoke-RestMethod -Uri $CPCDevicesNextLink -Headers $authHeader -Method Get)
    $CPCDevicesNextLink = $CPCDevicesResponse."@odata.nextLink"
    [array]$CPCDevices += $CPCDevicesResponse.value
}

# Get all Azure AD objects with extensionAttribute2 filled
$AADDevices = @()
$Uri = "https://graph.microsoft.com/v1.0/devices?`$filter=extensionAttributes/extensionAttribute2 ne null&`$count=true&ConsistencyLevel=eventual"

$AADDevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get)
[array]$AADDevices = $AADDevicesResponse.value | Select-Object id, DisplayName, accountEnabled, enrollmentProfileName, extensionAttributes
$AADDevicesNextLink = $AADDevicesResponse."@odata.nextLink"
while ($null -ne $AADDevicesNextLink) {
    $AADDevicesResponse = (Invoke-RestMethod -Uri $AADDevicesNextLink -Headers $authHeader -Method Get)
    $AADDevicesNextLink = $AADDevicesResponse."@odata.nextLink"
    [array]$AADDevices += $AADDevicesResponse.value | Select-Object id, DisplayName, accountEnabled, enrollmentProfileName, extensionAttributes
}

$checkCount = 0
$harvestedCount = 0
$clearedCount = 0
$activeCount = 0
$inactiveCount = 0

# Create the list for Cloud PC's that are harvested
Set-Content -Path $harvestedDevicesCSV -Value "managedDeviceName,status,lastActivityInDays,userPrincipalName,provisioningPolicyName,adProvGroupName,servicePlanName,adLicenseGroupName,harvestedDate" -Encoding Unicode

if(-not(!$AADDevices)){
    Write-output "$($AADDevices.count) Cloud PC's found with extensionAttribute2 configured start harvesting process"
    Write-Log -LogOutput ("$($AADDevices.count) Cloud PC's found with extensionAttribute2 configured start harvesting process") -Path $LogFile
    
    # Get only Cloud PC's that have the extensionAttribute2 configured and check for harvesting
    $cpcToHarvest = $CPCDevices | Where-Object {$_.managedDeviceName -in $AADDevices.displayName}
    
    foreach($cpc in $cpcToHarvest){  
        # Refresh token when it's expiring
        if (((($token.ExpiresOn.UtcTicks)-(([System.DateTime]::UtcNow).ticks))/10000000) -le 300){
        . .\GenMSALToken.ps1}

        $checkCount += 1

        # Check if the CPC user logged in recently if not use extensionAttribute2
        try {
            $RealTimeRemoteConnectionStatus = (Get-CPCDeviceRemoteConnectionStatus -id $cpc.id)
            $RealTimeRemoteConnectionDateTime = $RealTimeRemoteConnectionStatus.GetValue(4)

            $lastActivityDateTime = ($RealTimeRemoteConnectionDateTime | Foreach-Object {[System.DateTimeOffset]$_} | Measure-Latest).DateTime
            $lastActivityInDays = (New-TimeSpan -Start $lastActivityDateTime -End $currentTime).Days
        } 
        catch {
            # If no logged on user is found the extensionAttribute2 will be used        
            $extensionAttribute2 = (Get-AADDevice -displayName $($cpc.managedDeviceName)).extensionAttributes.extensionAttribute2
            $lastActivityDateTime = [DateTime]$extensionAttribute2
            $lastActivityInDays = (New-TimeSpan -Start $lastActivityDateTime -End $currentTime).Days
        }
                    
        # Check if CPC user is not member of VIP group
        $membersSID = (Get-ADGroupMember -Identity $noRevokeGroup -Recursive -Server $Server -Credential $psCredential | Select-Object -ExpandProperty SID).value

        # Get userSID from CPC user by using userPrincipalName
        $userSID = (Get-ADUser -Filter "userPrincipalName -eq '$($cpc.userPrincipalName)'" -Server $Server -Credential $psCredential).SID.Value

        # Get userSID from CPC user by using samAccountName
        if(!$userSID){
            $samAccountName = $($cpc.userPrincipalName) -replace $UPN, ''
            $userSID = (Get-ADUser -Filter "samAccountName -eq '$samAccountName'" -Server $Server -Credential $psCredential).SID.Value
        }
 
        # If CPC user is found continue
        if(-not(!$userSID)){

            # When the CPC user is not a member of the VIP group proceed
            if($membersSID -notcontains $userSID){
                
                # When the inactiveMinimumInDays is not met
                if($lastActivityInDays -ge $inactiveThresholdInDays){
                    Write-output "$($cpc.managedDeviceName) last activity $lastActivityInDays days ago start harvesting"
                    Write-Log -LogOutput ("$($cpc.managedDeviceName) last activity $lastActivityInDays days ago start harvesting") -Path $LogFile

                    # Check if user has multiple devices to determine if provisioning group can be removed
                    $AllUserCPCDevices = Get-AllUserCPCDevices -userPrincipalName $cpc.userPrincipalName
                    $provisioningPolicies = $AllUserCPCDevices.provisioningPolicyName
                    $provisioningPolicies = $provisioningPolicies | Where-Object {$_ -eq $cpc.provisioningPolicyName}

                    if($provisioningPolicies.count -eq 1){
                        $groupId = (Get-CPCProvisioningPolicy -id $cpc.provisioningPolicyId).assignments.id
                        $uri = "https://graph.microsoft.com/v1.0/groups/$groupId"
                        $adProvGroupName = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).onPremisesSamAccountName
                            
                        # Check if provisioning group is found
                        $adProvGroup = Get-ADGroup -Filter {Name -eq $adProvGroupName} -Properties *

                        # Remove provisioning group membership for user
                        if(-not(!$adProvGroup)){
                            #Remove-ADGroupMember -Identity $adProvGroup.Name -Members $userSID -Server $Server -Credential $psCredential -Confirm:$false
                            Write-output "$($cpc.UserPrincipalName) removed from AD provisioning group $($adProvGroup.Name)"
                            Write-Log -LogOutput ("$($cpc.UserPrincipalName) removed from AD provisioning group $($adProvGroup.Name)") -Path $LogFile
                        }
                        else{
                            Write-Warning "Provisioning group $($cpc.provisioningPolicyName) not found in Active Directory"
                        }
                    }
                    else{
                        Write-output "$($cpc.userPrincipalName) has another Cloud PC assigned to provisioning policy $($cpc.provisioningPolicyName) stop removing user from provisioning group $adProvGroupName"
                        Write-Log -LogOutput ("$($cpc.userPrincipalName) has another Cloud PC assigned to provisioning policy $($cpc.provisioningPolicyName) stop removing user from provisioning group $adProvGroupName") -Path $LogFile
                    }

                    # Construct license group name
                    $sp = $cpc.servicePlanName
                    $c = $sp.Split("/")[-3] # cores
                    $cores = ($c -replace "[^0-9]" , '') + "C"
                    $ram = ($sp.Split("/")[-2]).replace("B","") # ram
                    $disk = ($sp.Split("/")[-1]).replace("B","") # disk

                    $adLicenseGroupName = "SG_CPC_License_<cores><ram><disk>"
                    $adLicenseGroupName = $adLicenseGroupName.Replace('<cores>', $cores)
                    $adLicenseGroupName = $adLicenseGroupName.Replace('<ram>', $ram)
                    $adLicenseGroupName = $adLicenseGroupName.Replace('<disk>', $disk)

                    # Check if license group is found
                    $adLicenseGroup = Get-ADGroup -Filter {Name -eq $adLicenseGroupName} -Properties *

                    if (-not(!$adLicenseGroup)){
                        #Remove-ADGroupMember -Identity $adLicenseGroup.Name -Members $userSID -Server $Server -Credential $psCredential -Confirm:$false
                        Write-output "$($cpc.userPrincipalName) removed from AD license group $adLicenseGroupName"
                        Write-Log -LogOutput ("$($cpc.userPrincipalName) removed from AD license group $adLicenseGroupName") -Path $LogFile

                        # Remove device from inactive devices list
                        $harvestedCount += 1
                            
                        # Add CPC device to harvested devices list
                        $harvestedDate = ([System.DateTimeOffset]::Now).DateTime

                        "{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f $($cpc.managedDeviceName),$($cpc.status),$lastActivityInDays,$($cpc.userPrincipalName),$($cpc.provisioningPolicyName),$adProvGroupName,$($cpc.servicePlanName),$adLicenseGroupName,$harvestedDate | Add-Content -Path $harvestedDevicesCSV -Encoding Unicode
                        
                        Write-output "$($cpc.managedDeviceName) harvesting process finished add to $harvestedDevicesFileName"
                        Write-Log -LogOutput ("$($cpc.managedDeviceName) harvesting process finished add to $harvestedDevicesFileName") -Path $LogFile
                    }
                    else {
                        Write-Warning "License group $adLicenseGroupName not found in AD stop harvesting process for $($cpc.managedDeviceName)"
                    }
                }
                else {
                    # Cloud PC extensionAttribute2 will be cleared if it does not met the inactiveMinimumInDays
                    if ($lastActivityInDays -lt $inactiveMinimumInDays){

                        # Clear extensionAttribute2
                        $objectId = (Get-AADDevice -displayName $($cpc.managedDeviceName)).id
                        Update-DeviceExtensionAttribute -Id $objectId -ExtensionAttributeKey $ExtensionAttributeKey -ExtensionAttributeValue $null

                        $clearedCount += 1
                        Write-output "$($cpc.managedDeviceName) is used $lastActivityInDays ago clear extensionAttribute2"
                        Write-Log -LogOutput ("$($cpc.managedDeviceName) is used $lastActivityInDays ago clear extensionAttribute2") -Path $LogFile

                    }
                    else {
                        # Cloud PC extensionAttribute will remain but is not eligible for harvesting because it does not met inactiveThresholdInDays
                        Write-output "$($cpc.managedDeviceName) is used $lastActivityInDays days ago extensionAttribute2 will not be cleared"                                   
                        Write-Log -LogOutput ("$($cpc.managedDeviceName) is used $lastActivityInDays days ago extensionAttribute2 will not be cleared") -Path $LogFile
                    } 
                }
            }
            else {         
                # Cloud PC extensionAttribute2 will be cleared if the CPC user is member of the VIP group
                $objectId = (Get-AADDevice -displayName $($cpc.managedDeviceName)).id
                Update-DeviceExtensionAttribute -Id $objectId -ExtensionAttributeKey $ExtensionAttributeKey -ExtensionAttributeValue $null

                $clearedCount += 1   
                Write-output "$($cpc.userPrincipalName) is member of $noRevokeGroup clear extensionAttribute2 for $($cpc.managedDeviceName)"
                Write-Log -LogOutput ("$($cpc.userPrincipalName) is member of $noRevokeGroup clear extensionAttribute2 for $($cpc.managedDeviceName)") -Path $LogFile
            }
        }
        else {
            Write-output "User not found for $($cpc.managedDeviceName)"
            Write-Log -LogOutput ( "User not found for $($cpc.managedDeviceName)") -Path $LogFile
        }
    }
}
else{
    Write-Output "No Cloud PC's found to harvest"
    Write-Log -LogOutput ("No Cloud PC's found to harvest") -Path $LogFile
}

Write-output "Finished checking Cloud PC's with extensionAttribute2 for harvesting"
Write-Log -LogOutput ("Finished checking Cloud PC's with extensionAttribute2 for harvesting") -Path $LogFile
Write-Log -LogOutput ("") -Path $LogFile
Write-output "Checking all other Cloud PC's for inactivity..."
Write-Log -LogOutput ("Checking all other Cloud PC's for inactivity...") -Path $LogFile

# Get only Cloud PC's that have not the extensionAttribute2 configured
$cpcToCheck = $CPCDevices | Where-Object {$_.managedDeviceName -notin $AADDevices.displayName}

foreach($cpc in $cpcToCheck){
    # Refresh token when it's expiring
    if (((($token.ExpiresOn.UtcTicks)-(([System.DateTime]::UtcNow).ticks))/10000000) -le 300){
    . .\GenMSALToken.ps1}

    # Check Cloud PC remote connection status to get the lastSignedInDateTime for the CPC user
    try{
        $RealTimeRemoteConnectionStatus = (Get-CPCDeviceRemoteConnectionStatus -id $cpc.id)
        $RealTimeRemoteConnectionDateTime = $RealTimeRemoteConnectionStatus.GetValue(4)

        $lastSignedInDateTime = ($RealTimeRemoteConnectionDateTime | Foreach-Object {[System.DateTimeOffset]$_} | Measure-Latest).DateTime
        $lastSignedInDays = (New-TimeSpan -Start $lastSignedInDateTime -End $currentTime).Days
    } 
    catch{
        # If no lastSignedInDateTime is found continue with enrollmentDateTime and constructedSignedInDateTime
        $enrollmentDateTime = ([System.DateTimeOffset](Get-ManagedDevice -id $cpc.managedDeviceId).enrolledDateTime).DateTime
        $enrollmentInDays = (New-TimeSpan -Start $enrollmentDateTime -End $currentTime).Days

        # If no lastSignedInDateTime is found it will be constructed with currentTime minus inactiveMinimumInDays so it will match the minimum threshold
        # Otherwise Cloud PC's without lastSignedInUser could never be marked as inactive
        $constructSignedInDateTime = ([System.DateTimeOffset]::Now).AddDays(-$inactiveMinimumInDays).DateTime
        $constructedSignedInDateTime = $constructSignedInDateTime.AddDays(-1)
        $constructedInDays = (New-TimeSpan -Start $constructedSignedInDateTime -End $currentTime).Days
    }

    # Check if CPC user is not member of VIP group
    $membersSID = (Get-ADGroupMember -Identity $noRevokeGroup -Recursive -Server $Server -Credential $psCredential | Select-Object -ExpandProperty SID).value

    # Get userSID from CPC user by using userPrincipalName
    $userSID = (Get-ADUser -Filter "userPrincipalName -eq '$($cpc.userPrincipalName)'" -Server $Server -Credential $psCredential).SID.Value

    # Get userSID from CPC user by using samAccountName
    if(!$userSID){
        $samAccountName = $($cpc.userPrincipalName) -replace $UPN, ''
        $userSID = (Get-ADUser -Filter "samAccountName -eq '$samAccountName'" -Server $Server -Credential $psCredential).SID.Value
    }

    # If CPC user is found continue otherwise skip device
    if(-not(!$userSID)){

        # When CPC user is not member of VIP group proceed
        if($membersSID -notcontains $userSID){

             # When the inactiveMinimumInDays is met or greater for lastSignedInDays or enrollmentInDays and constructedInDays
            # To prevent that recently enrolled Cloud PC's with no lastSignedInUser are marked as inactive
            if($lastSignedInDays -ge $inactiveMinimumInDays){
                $inactiveCount += 1
 
                 # Update extensionAttribute2 with lastSignedInDateTime
                 $objectId = (Get-AADDevice -displayName $($cpc.managedDeviceName)).id
                 Update-DeviceExtensionAttribute -Id $objectId -ExtensionAttributeKey $ExtensionAttributeKey -ExtensionAttributeValue $lastSignedInDateTime
 
                 Write-output "$($cpc.managedDeviceName) set $ExtensionAttributeKey to lastSignedInDateTime: $lastSignedInDateTime"
                 Write-Log -LogOutput ("$($cpc.managedDeviceName) set $ExtensionAttributeKey to lastSignedInDateTime: $lastSignedInDateTime") -Path $LogFile
             
             } elseif(($constructedInDays -ge $inactiveMinimumInDays) -and ($enrollmentInDays -ge $inactiveMinimumInDays)){
                 $inactiveCount += 1
 
                 # Update extensionAttribute2 with constructedSignedInDateTime
                 $objectId = (Get-AADDevice -displayName $($cpc.managedDeviceName)).id
                 Update-DeviceExtensionAttribute -Id $objectId -ExtensionAttributeKey $ExtensionAttributeKey -ExtensionAttributeValue $constructedSignedInDateTime
                 
                 Write-output "$($cpc.managedDeviceName) set $ExtensionAttributeKey to constructedSignedInDateTime: $constructedSignedInDateTime"
                 Write-Log -LogOutput ("$($cpc.managedDeviceName) set $ExtensionAttributeKey to constructedSignedInDateTime: $constructedSignedInDateTime") -Path $LogFile
             }
             else{
                 $activeCount += 1
             }
        }
        else{
            Write-output "$($cpc.userPrincipalName) in VIP group do not set $ExtensionAttributeKey for $($cpc.managedDeviceName)"
            Write-Log -LogOutput ("$($cpc.userPrincipalName) in VIP group do not set $ExtensionAttributeKey for $($cpc.managedDeviceName)") -Path $LogFile
        }
    }
    else{
        # Do nothing when no CPC user is found
        Write-output "$($cpc.managedDeviceName) no user found"
        Write-Log -LogOutput ( "$($cpc.managedDeviceName) no user found") -Path $LogFile 
    }
}

Write-output "Finished checking all other Cloud PC's for inactivity"
Write-output ""
Write-output "$($CPCDevices.count) Cloud PC's total"
Write-output "$checkCount Cloud PC's with configured extensionAttribute2"
Write-output "$clearedCount Cloud PC's with cleared extensionAttribute2"
Write-output "$harvestedCount Cloud PC's harvested"
Write-output "$($cpcToCheck.id.count) Cloud PC's processed"
Write-output "$activeCount Cloud PC's active"
Write-output "$inactiveCount Cloud PC's that have the extensionAttribute2 set"

Write-Log -LogOutput ("Finished checking all other Cloud PC's for inactivity") -Path $LogFile
Write-Log -LogOutput ("") -Path $LogFile
Write-Log -LogOutput ("$($CPCDevices.count) Cloud PC's total") -Path $LogFile
Write-Log -LogOutput ("$checkCount Cloud PC's with configured extensionAttribute2") -Path $LogFile
Write-Log -LogOutput ("$clearedCount Cloud PC's with cleared extensionAttribute2") -Path $LogFile
Write-Log -LogOutput ("$harvestedCount Cloud PC's harvested") -Path $LogFile
Write-Log -LogOutput ("$($cpcToCheck.id.count) Cloud PC's processed") -Path $LogFile
Write-Log -LogOutput ("$activeCount Cloud PC's active") -Path $LogFile
Write-Log -LogOutput ("$inactiveCount Cloud PC's that have the extensionAttribute2 set") -Path $LogFile

# Upload the harvested devices to SharePoint and remove in temp
$emptyCheck = @()
try {
    $emptyCheck = Import-CSV $harvestedDevicesCSV
    if($null -ne $emptyCheck){
        Write-output "Uploading $harvestedDevicesFileName to SharePoint"
        $dummy = Add-PnPFile -Path $harvestedDevicesCSV -Folder $DestinationPath
    }
    else {Write-output "CSV file $harvestedDevicesFileName is empty"}
} catch {
    "$harvestedDevicesFileName not found"
}

Write-Output "License harvesting process is finished"
Write-Log -LogOutput ("License harvesting process is finished") -Path $LogFile

# Always upload the log file
Write-output "Uploading $LogFileName to SharePoint"
$dummy = Add-PnPFile -Path $LogFile -Folder $DestinationPath

# Clean remaining files from hybrid worker temp folder
$ItemsToRemove = @($harvestedDevicesCSV,$LogFile)
foreach ($Item in $ItemsToRemove){
    try {
        Remove-item $Item -ErrorAction SilentlyContinue
    } catch {
        #Item already removed or cannot be found
    }
}