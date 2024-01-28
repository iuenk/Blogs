#=============================================================================================================================
#
# Script Name:     RebootUnresponsiveCPC.ps1
# Description:     Reboot all Windows 365 Cloud PC's that are not communicating with Intune for 2 days.
#   
# Notes      :     It will reboot the Windows 365 Cloud PC and send upload a report to SharePoint containing all devices
#                  that were rebooted during that run.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

. .\GENMSALToken.ps1
. .\GenUploadSPO.ps1

#Configure variables
$days = 2
$daysago = "{0:s}" -f (get-date).AddDays(-$days) + "Z"
$CurrentTime = [System.DateTimeOffset]::Now
$Path = "$env:TEMP"
$FileName = "CPC" + "-" + "RebootedDevices" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".csv"
$RebootedDevicesCSV = "$Path\$FileName"
$SiteURL = Get-AutomationVariable -Name "siteurl"
$DestinationPath = Get-AutomationVariable -Name "reportDestination"

Function Restart-CPCDevice(){

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)] $id
)

# Defining Variables
$Resource = "deviceManagement/virtualEndpoint/cloudPCs"
$graphApiVersion = "beta"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/reboot"
        (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post).Value
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

# Get all CPC devices from Intune
$ManagedDevices = @()
$Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=startsWith(deviceName,'CPC-') and lastSyncDateTime le $daysago"

$ManagedDevicesResponse = (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method Get)
[array]$ManagedDevices = $ManagedDevicesResponse.value | Select-Object id,deviceName,lastSyncDateTime,complianceState
$ManagedDevicesNextLink = $ManagedDevicesResponse."@odata.nextLink"
while ($null -ne $ManagedDevicesNextLink) {
    $ManagedDevicesResponse = (Invoke-RestMethod -Uri $ManagedDevicesNextLink -Headers $authHeader -Method Get)
    $ManagedDevicesNextLink = $ManagedDevicesResponse."@odata.nextLink"
    [array]$ManagedDevices += $ManagedDevicesResponse.value | Select-Object id,deviceName,lastSyncDateTime,complianceState
}

# Get all Cloud PC devices that are in $ManagedDevices
$CPCDevices = @()
$Uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=status eq 'provisioned'"

$CPCDevicesResponse = (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method Get)
[array]$CPCDevices = $CPCDevicesResponse.value | Where-Object {$_.managedDeviceName -in $ManagedDevices.deviceName} | Select-Object id,managedDeviceName,userPrincipalName
$CPCDevicesNextLink = $CPCDevicesResponse."@odata.nextLink"
while ($null -ne $CPCDevicesNextLink) {
    $CPCDevicesResponse = (Invoke-RestMethod -Uri $CPCDevicesNextLink -Headers $authHeader -Method Get)
    $CPCDevicesNextLink = $CPCDevicesResponse."@odata.nextLink"
    [array]$CPCDevices += $CPCDevicesResponse.value | Where-Object {$_.managedDeviceName -in $ManagedDevices.deviceName} | Select-Object id,managedDeviceName,userPrincipalName
}

Write-Output "Creating the list..."
Set-Content -Path $RebootedDevicesCSV -Value "intuneId,cpcId,deviceName,lastSyncInDays,complianceState,userPrincipalName"

# Filter with only provisioned devices
$ManagedDevices = $ManagedDevices | Where-Object {$_.deviceName -in $CPCDevices.managedDeviceName}
Write-Output "There are $($ManagedDevices.count) CPC devices that haven't synced in the last $days days..."

foreach ($ManagedDevice in $ManagedDevices){
    $CPCDevice = $CPCDevices | Where-Object {$_.ManagedDeviceName -eq $ManagedDevice.deviceName}
    Write-Output "$($CPCDevice.managedDeviceName): start rebooting process."
    try {

        # Get LastSyncDate in days ago
        $LSD = $ManagedDevice.lastSyncDateTime
        $LastSyncTime = [datetimeoffset]::Parse($LSD)
        $TimeDifference = $CurrentTime - $LastSyncTime
        Write-Output "$($CPCDevice.managedDeviceName): last synced $($TimeDifference.days) days ago..."
        Restart-CPCDevice -id $CPCDevice.id
        Write-Output "$($CPCDevice.managedDeviceName): reboot device."

        # Add Azure AD Device to CSV file
        "{0},{1},{2},{3},{4},{5}" -f $ManagedDevice.id,$CPCDevice.id,$CPCDevice.managedDeviceName,$($TimeDifference.days),$ManagedDevice.complianceState,$CPCDevice.userPrincipalName | Add-Content -Path $RebootedDevicesCSV -Encoding Unicode
    }
    catch {
        Write-Warning "$($CPCDevice.managedDeviceName): failed to reboot device."
        Write-Warning $_.Exception.Message
        Write-Output ""
        break
    } 
        
}

# Upload to Sharepoint and remove in temp
$emptyCheck = @()
$emptyCheck = Import-CSV $RebootedDevicesCSV
if($null -ne $emptyCheck){
    # Upload CSV to SharePoint and remove the CSV in temp directory
    Write-output "Uploading $RebootedDevicesCSV to SharePoint"
    Upload-SPO -filename $RebootedDevicesCSV -siteurl $SiteURL -destinationpath "$DestinationPath/CPC_Rebooted"
}
else {
    Write-output "CSV file is empty"
}
Remove-Item -Path $RebootedDevicesCSV