#=============================================================================================================================
#
# Script Name:     FormsW11UpdateRequests.ps1
# Description:     This Azure automation runbook will be triggered by an Azure Logic App.
#   
# Notes      :     The runbook will add user and device to specified security groups. The security group is assigned to the
#                  Windows 11 feature package. In about 30 minutes the Windows 10 device will receive the update to Windows 11.     
#
# Created by :     Ivo Uenk
# Date       :     28-1-2024
# Version    :     1.0
#=============================================================================================================================

Param (
  [string] $hostname,
  [string] $UPN
)

. .\GenMSALToken.ps1
. .\GenMail.ps1
. .\GenUploadSPO.ps1

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

#variables
$LocalPath = "$env:TEMP"
$LogFile = $LocalPath + "\" + "$Hostname" + "_" + ((Get-Date).ToString("yyyyMMdd-HHmm")) + ".log"
$SiteURL = Get-AutomationVariable -Name "siteurl"
$DestinationPath = Get-AutomationVariable -Name "reportDestination"

$RecipientCC = Get-AutomationVariable -Name "MailRecipient"
$RecipientsCC = $RecipientCC.Split(",")
$MailSender = Get-AutomationVariable -Name "MailSender"
$Subject = "Issue with your W11 Update request"

$UserTargetGroupName = Get-AutomationVariable -Name userTargetGroup
$DeviceTargetGroupName = Get-AutomationVariable -Name DeviceTargetGroup
#end variables

#start
Write-Log "Starting Runbook to handle W11 update request through Forms..." -path $logFile
Write-Log "Inputs are: Hostname: [$Hostname] UPN: [$UPN]" -path $logFile

$verifyUser = 0
$verifyDevice = 0

#Verifying User target group and UPN existence
try {
    $uri = "https://graph.microsoft.com/v1.0/groups/?`$filter=displayName eq `'$($UserTargetGroupName)`'&`$select=id,displayName"
    $UserTargetGroup = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value

    if(-not(!$UserTargetGroup)){
        try{
            #get user
            $uri = "https://graph.microsoft.com/v1.0/users/$UPN"
            $User = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get)

            if(-not(!$User)){
                # Get user groupmemberships
                $uri = "https://graph.microsoft.com/v1.0/users/$($user.id)/memberOf?`$select=id,displayName"
                $UserGrpMemberships = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value

                Write-output "Verified User target group [$UserTargetGroupName] and UPN [$UPN] existence."
                Write-Log "Verified User target group [$UserTargetGroupName] and UPN [$UPN] existence." -path $logFile  
            }
            else{
                $verifyUser += 1
                Write-output "User $User not found!"
                Write-Log "User $User not found!" -path $logFile
            }
        } 
        catch{
            $verifyUser += 1
            Write-output "No permissions to retrieve user details."
            Write-Log "No permissions to retrieve user details." -path $logFile
        }
    }
    else{
        $verifyUser += 1
        Write-output "UserTargetGroup [$UserTargetGroupName] not found!"
        Write-Log "UserTargetGroup [$UserTargetGroupName] not found!" -path $logFile
    }
} 
catch{
    $verifyUser += 1
    Write-output "No permissions to retrieve groups."
    Write-Log "No permissions to retrieve groups." -path $logFile
}

#Verifying Device target group and Hostname existence
if(0 -eq $verifyUser){
    #Groups graph permissions already checked earlier no need for try catch
    $uri = "https://graph.microsoft.com/v1.0/groups/?`$filter=displayName eq `'$($DeviceTargetGroupName)`'&`$select=id,displayName"
    $DeviceTargetGroup = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value

    if(-not(!$DeviceTargetGroup)){
        try{
            #Get device
            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/?`$filter=deviceName eq `'$($hostname)`'"
            $Device = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value

            if(-not(!$Device)){
                Write-output "Verified Device target group [$DeviceTargetGroupName] and Hostname [$Hostname] existence."
                Write-Log "Verified Device target group [$DeviceTargetGroupName] and Hostname [$Hostname] existence." -path $logFile

                # Send email to requestor if devices' registered UPN does not match requestor
                if($($Device.Userprincipalname) -eq $($user.userPrincipalName)){
                    Write-output "Verified Device [$Hostname] registered UserPrincipalname matches UPN [$UPN]."
                    Write-Log "Verified Device [$Hostname] registered UserPrincipalname matches UPN [$UPN]." -path $logFile

                    try{
                        #Get device
                        $DevAADID = $($device.azureADDeviceId)
                        $uri = "https://graph.microsoft.com/v1.0/devices(deviceId='$DevAADID')?`$select=id"
                        $DeviceAADObjectID = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).id

                        #Getting device groupmemberships"
                        $uri = "https://graph.microsoft.com/v1.0/devices(deviceId='$DevAADID')/memberOf?`$select=id,displayName"
                        $DeviceGrpMemberships = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value

                        Write-output "Retrieved the device [$Hostname] groupmemberships."
                        Write-Log "Retrieved the device [$Hostname] groupmemberships." -path $logFile
                    } 
                    catch{
                        $verifyDevice += 1
                        Write-output "No permissions to retrieve AAD device info."
                        Write-Log "No permissions to retrieve AAD device info." -path $logFile  
                    }
                }
                else{
                    Write-output "Provided hostname [$Hostname] is not registered to provided UPN [$UPN] sending email."
                    Write-Log "Provided hostname [$Hostname] is not registered to provided UPN [$UPN] sending email." -path $logFile
                    
                    try{
                        $Recipients = $($user.mail)
                        $UserGivenName = $($User.GivenName)

                        $body = "Dear $UserGivenName,<br><br>
                        The hostname `'$($Hostname)`' provided in your Forms request for a Windows 11 update is not registered to you, therefor the request is not processed.
                        <br>Please verify the hostname you provided and try again through the same Form.
                        <br><br>Kind regards,<br>CDS Squad Automation
                        <br><br>PS: This is non-monitored mailbox, replies are not read."
                        
                        Send-Mail -Recipients $Recipients -recipientscc $RecipientsCC -Subject $Subject -Body $Body -MailSender $MailSender
                        Write-output "Email sent successfully to user [$UPN]."
                        Write-Log "Email sent successfully to user [$UPN]." -path $logFile
                    } 
                    catch{
                        $verifyDevice += 1
                        Write-output "Error on sending NotPrimaryUPNEmail to user [$UPN]."
                        Write-Log "Error on sending NotPrimaryUPNEmail to user [$UPN]." -path $logFile
                    }
                }
            }
            else{
                $verifyDevice += 1
                Write-output "Device not found based on Hostname [$Hostname] emailing user [$UPN]."
                Write-Log "Device not found based on Hostname [$Hostname] emailing user [$UPN]." -path $logFile

                try{
                    $Recipients = $($user.mail)
                    $UserGivenName = $($User.GivenName)

                    $body = "Dear $UserGivenName,<br><br>
                    The hostname `'$($Hostname)`' provided in your Forms request for a Windows 11 update could not be verified and therefor no action is taken.
                    <br>Please verify the hostname you provided and try again through the same Form.
                    <br><br>Kind regards,<br>CDS Squad Automation
                    <br><br>PS: This is non-monitored mailbox, replies are not read."
                    
                    Send-Mail -Recipients $Recipients -recipientscc $RecipientsCC -Subject $Subject -Body $Body -MailSender $MailSender
                    Write-output "Email sent successfully to user [$UPN]."
                    Write-Log "Email sent successfully to user [$UPN]." -path $logFile
                } 
                catch{
                    $verifyDevice += 1
                    Write-output "Error on sending DeviceNotFoundEmail to user [$UPN]"
                    Write-Log "Error on sending DeviceNotFoundEmail to user [$UPN]" -path $logFile
                }
            }
        }
        catch {
            $verifyDevice += 1
            Write-output "No permissions to retrieve device details."
            Write-Log "No permissions to retrieve device details." -path $logFile
        }
    }
    else{
        $verifyDevice += 1
        Write-output "DeviceTargetGroup [$DeviceTargetGroupName] not found!"
        Write-Log "DeviceTargetGroup [$DeviceTargetGroupName] not found!" -path $logFile
    }
}
else{
    Write-Log "Error occured retrieving User target group [$UserTargetGroupName] or UPN [$UPN]." -path $logFile
    Upload-SPO -filename $logFile -siteurl $SiteURL -destinationpath "$DestinationPath/FormsW11UpdateRequests"
    Remove-item $logFile -ErrorAction SilentlyContinue

    Write-Error "Error occured retrieving User target group [$UserTargetGroupName] or UPN [$UPN]."
}

#Verify if user is member of target group otherwise add user
if(0 -eq $verifyDevice){
    if($UserGrpMemberships.displayname -notcontains $($UserTargetGroup.displayName)){
        try{
            $bodyProcess = @{
                "@odata.id"= "https://graph.microsoft.com/v1.0/directoryObjects/$($User.id)"  
            }
            $body = $bodyProcess | ConvertTo-Json
            
            $Uri = "https://graph.microsoft.com/v1.0/groups/$($usertargetgroup.id)/members/`$ref"
            (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method POST -ContentType "application/json" -Body $Body)

            Write-output "Added user [$UPN] to UserTargetgroup [$UserTargetGroupName]."
            Write-Log "Added user [$UPN] to UserTargetgroup [$UserTargetGroupName]."  -path $logFile
        }
        catch{
            Write-output "Error in adding user [$UPN] to UserTargetGroup [$UserTargetGroupName]."
            Write-Log "Error in adding user [$UPN] to UserTargetGroup [$UserTargetGroupName]." -path $logFile
        }
    }elseif($UserGrpMemberships.displayname -contains $($UserTargetGroup.displayName)){
        Write-output "User [$UPN] already member of UserTargetgroup [$UserTargetGroupName]."
        Write-Log "User [$UPN] already member of UserTargetgroup [$UserTargetGroupName]."  -path $logFile
    }

    #Verify if device is member of target group otherwise add device
    if($DeviceGrpMemberships.displayname -notcontains $($DeviceTargetGroup.displayName)){
        try{
            $bodyProcess = @{           
                "@odata.id"= "https://graph.microsoft.com/v1.0/directoryObjects/$DeviceAADObjectID"  
            }
            $body = $bodyProcess | ConvertTo-Json
            
            $Uri = "https://graph.microsoft.com/v1.0/groups/$($Devicetargetgroup.id)/members/`$ref"
            (Invoke-RestMethod -Uri $Uri -Headers $authHeader -Method POST -ContentType "application/json" -Body $Body)

            Write-output "Added device [$Hostname] to DeviceTargetGroup [$DeviceTargetGroupName]."
            Write-Log "Added device [$Hostname] to DeviceTargetGroup [$DeviceTargetGroupName]." -path $logFile
        }
        catch{
            Write-output "Error in adding device [$Hostname] to DeviceTargetGroup [$DeviceTargetGroupName]."
            Write-Log "Error in adding device [$Hostname] to DeviceTargetGroup [$DeviceTargetGroupName]." -path $logFile
        }
    }elseif ($DeviceGrpMemberships.displayname -contains $($DeviceTargetGroup.displayName)) {
        Write-output "Device [$Hostname] already member of DeviceTargetgroup [$DeviceTargetGroupName]."
        Write-Log "Device [$Hostname] already member of DeviceTargetgroup [$DeviceTargetGroupName]." -path $logFile
    }
}
else{
    Write-Log "Error occured retrieving DeviceTargetGroup [$DeviceTargetGroupName] or Hostname [$Hostname]." -path $logFile
    Upload-SPO -filename $logFile -siteurl $SiteURL -destinationpath "$DestinationPath/FormsW11UpdateRequests"
    Remove-item $logFile -ErrorAction SilentlyContinue

    Write-Error "Error occured retrieving DeviceTargetGroup [$DeviceTargetGroupName] or Hostname [$Hostname]."
}

if((0 -eq $verifyUser) -and (0 -eq $verifyDevice)){
    Write-output "All actions taken and script completed successfully. Proceeding to upload log."
    Write-Log "All actions taken and script completed successfully. Proceeding to upload log."  -path $logFile
    Upload-SPO -filename $logFile -siteurl $SiteURL -destinationpath "$DestinationPath/FormsW11UpdateRequests"
    Remove-item $logFile -ErrorAction SilentlyContinue
}