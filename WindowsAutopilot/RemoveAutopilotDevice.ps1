#=============================================================================================================================
#
# Script Name:     RemoveAutopilotDevice.ps1
# Description:     Get Autopilot CSV's from SharePoint and remove in Autopilot based on specified criteria.
#   
# Notes      :     Get Autopilot CSV's from SharePoint and remove in Autopilot based on specified criteria.
#                  Check URL's if Autopilot service is running otherwise this script will run till timeout see https://social.technet.microsoft.com/Forums/en-US/6f175627-a568-43d4-b518-26e6d049d659/something-went-wrong-oobeaadv10?forum=microsoftintuneprod.
#                  The $Dummy variable before Add-pnpfile can be necessary due to a bug see https://github.com/pnp/PnP-PowerShell/issues/918.
#                  Device will be removed if the owner has sufficient permissions on the grouptag. 
#
# Created by :     Ivo Uenk
# Date       :     3-5-2024
# Version    :     2.4
#=============================================================================================================================

. .\GenMSALToken.ps1
. .\GenMail.ps1

#Requires -Module  PnP.PowerShell

# Variables
$PathCsvFiles = "$env:TEMP"
$checkedCombinedOutput = "$pathCsvFiles\checkedcombinedoutput.csv"
$SiteURL = Get-AutomationVariable -Name "SiteUrlAP"
$ShortSiteURL = "/" + $SiteURL.split("/",4)[-1]
$removeAutopilotDeviceFolderPath = Get-AutomationVariable -Name "ReportFolderRemoveAP"
$Uris = "login.live.com", "login.microsoftonline.com", "portal.manage.microsoft.com", "EnterpriseEnrollment.manage.microsoft.com", "EnterpriseEnrollment-s.manage.microsoft.com"

$removeFolderPath = $ShortSiteURL + $removeAutopilotDeviceFolderPath + "/Remove"
$sourcesFolderPath = $ShortSiteURL + $removeAutopilotDeviceFolderPath + "/Sources"
$deletedFolderName = $ShortSiteURL + $removeAutopilotDeviceFolderPath + "/Deleted"
$errorsFolderName = $ShortSiteURL + $removeAutopilotDeviceFolderPath + "/Errors"
$LogFolderName = $ShortSiteURL + $removeAutopilotDeviceFolderPath + "/Logging"
$removeFolderSiteRelativeUrl = $removeAutopilotDeviceFolderPath + "/Remove"
$DevicesDeletedPath = $PathCsvFiles + "\" + "Autopilot-Deleted" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".csv"
$RemovedErrorsPath = $PathCsvFiles + "\" + "Autopilot-Remove-Errors" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".csv"
$LogFile = $PathCsvFiles + "\" + "Autopilot-Actions" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".log"
$MailSender = Get-AutomationVariable -Name "EmailAutomation"

$Label = Get-AutomationVariable -Name "cLabel"
$cLabel = $Label.Split(",")

# Credentials
try {
    $intuneAutomationCredential = Get-AutomationPSCredential -Name "ReadWriteAccount"
    $userName = $intuneAutomationCredential.UserName  
    $securePassword = $intuneAutomationCredential.Password
    $psCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $securePassword 

    Connect-PnPOnline -Url $SiteURL -Credentials $psCredential
} 
catch {
    Write-output "Cannot connect to Microsoft services"
    break
}

# Functions
function Remove-AutoPilotDevice(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)] $id
    )
        # Defining Variables
        $graphApiVersion = "beta"
        $Resource = "deviceManagement/windowsAutopilotDeviceIdentities"
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$id"

        try {
            Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Delete | Out-Null
        }
        catch {   
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
    
            Write-Output "Response content:`n$responseBody"
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
            break
        }     
}

function Get-AADUserGroupMembership(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $upn
)
    # Defining Variables
    $graphApiVersion = "v1.0"
    $Resource = "users"    
    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$upn/memberOf"

    try {
        # Necessary otherwise it will stop at 100 rows
        $GroupMembership = @()
        $GroupMembershipResponse = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get)
        [array]$GroupMembership = $GroupMembershipResponse.value
        $GroupMembership

        $GroupMembershipNextLink = $GroupMembershipResponse."@odata.nextLink"
        while ($null -ne $GroupMembershipNextLink) {
            $GroupMembershipResponse = (Invoke-RestMethod -Uri $GroupMembershipNextLink -Headers $authHeader -Method Get)
            $GroupMembershipNextLink = $GroupMembershipResponse."@odata.nextLink"
            [array]$GroupMembership += $GroupMembershipResponse.value
            $GroupMembership
        }
    }
    catch {   
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();

        Write-Output "Response content:`n$responseBody"
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        break
    }     
}

function Get-AADUserMail(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $UserPrincipalName
)
    # Defining Variables
    $graphApiVersion = "v1.0"
    $Resource = "users"    
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=UserPrincipalName eq '$UserPrincipalName'&`$select=mail&`$count=true&ConsistencyLevel=eventual"

    try {
        (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
    }
    catch {   
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();

        Write-Output "Response content:`n$responseBody"
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        break
    }     
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

# Get all files from RemoveAutopilotDevice folder stop if no files are found
$folderItems = Get-PnPFolderItem -FolderSiteRelativeUrl $removeFolderSiteRelativeUrl -ItemType File
if (!$folderItems) {
    Write-Output "No file(s) found in the Autopilot remove folder"
    break
}

# Check if Autopilot service is running break script if an URL is not reachable
foreach ($Uri in $Uris) {
    $Response = ""
    try {
        $Response = Invoke-WebRequest -Uri $Uri -ErrorAction SilentlyContinue -UseBasicParsing -DisableKeepAlive
    }
    catch {
        Write-Log -LogOutput ("$Uri not reachable.") -Path $LogFile
        Write-Output "$Uri not reachable"
        break
    }
}

$totalDevices = 0
$badDevices = @()
$successDevice = @()
$valuesToLookFor = @(
    'GSURO1-AutopilotImport'
)

######### Start first stage: download and prepare files #########
Write-Log -LogOutput ("Start first stage: download and prepare files.") -Path $LogFile

# Remove previous files if not cleanup up properly
Get-ChildItem -Path $PathCsvFiles | Where-Object {$_.Name -like "checkedcombinedoutput*"} | Remove-Item
Get-ChildItem -Path $PathCsvFiles | Where-Object {$_.Name -like "Autopilot*"} | Remove-Item

# Start downloading necessary files from SharePoint
$CSVtoRemove = @()

# Download CSV files from SharePoint
foreach($item in $folderItems){

    # Get filename and createdby
    $FileName = $item.Name
    $FileRelativeURL = ($removeFolderPath + "/" + $FileName)
    $File = Get-PnPFile -Url "$FileRelativeURL" -AsListItem
    $targetLibraryUrl = $sourcesFolderPath + '/' + $FileName

    # If file is CSV continue
    if($FileName -like "*.csv"){

        $obj = new-object psobject -Property @{
            FileName = $File["FileLeafRef"]
            CreatedBy = $File["Created_x0020_By"].Split("|",3)[-1]
        }
        $CSVtoRemove += $obj

        Get-PnPFile -Url $FileRelativeURL -Path $PathCsvFiles -FileName $FileName -AsFile -Force
        Write-Log -LogOutput ("File $FileName downloaded to $PathCsvFiles.") -Path $LogFile

        # Remove spaces in CSV file
        $PathCsvFile = $PathCsvFiles + '\' + $FileName
        $CsvToCheck = Import-Csv $PathCSVFile

        # Remove spaces in rows
        try {
            $CsvToCheck | Foreach-Object {
                $_.PSObject.Properties | Foreach-Object { $_.Value = $_.Value.Trim()}
                Write-Log -LogOutput ("$FileName fixed spaces in rows.") -Path $LogFile 
            }
        } catch {}

        # Export CSV
        ($CsvToCheck | ConvertTo-Csv -NoTypeInformation) -replace '"' | set-content $PathCsvFile
        
        # Move the file after being processed
        Move-PnPFile -SourceUrl $item.ServerRelativeUrl -TargetUrl $targetLibraryUrl -AllowSchemaMismatch -Force -Overwrite -AllowSmallerVersionLimitOnDestination
    }
    else {
        $obj = new-object psobject -Property @{
            SerialNumber = ""
            Owner = $($File["Created_x0020_By"].Split("|",3)[-1])
            Error = "($FileName bad file format)"
        }
        $badDevices += $obj
        Write-Log -LogOutput ("File $FileName not a valid CSV file.") -Path $LogFile

        # Move the file after being processed
        Move-PnPFile -SourceUrl $item.ServerRelativeUrl -TargetUrl $targetLibraryUrl -AllowSchemaMismatch -Force -Overwrite -AllowSmallerVersionLimitOnDestination
    }
}

if(-not(!$CSVtoRemove)){

    # Necessary otherwise it will stop at 1000 rows
    $APDevices = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
    $APDevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get)
    [array]$APDevices = $APDevicesResponse.value
    $APDevicesNextLink = $APDevicesResponse."@odata.nextLink"
    while ($null -ne $APDevicesNextLink) {
        $APDevicesResponse = (Invoke-RestMethod -Uri $APDevicesNextLink -Headers $authHeader -Method Get)
        $APDevicesNextLink = $APDevicesResponse."@odata.nextLink"
        [array]$APDevices += $APDevicesResponse.value
    }

    # Create CSV file with devices that will be removed
    Set-Content -Path $CheckedCombinedOutput -Value "Device Serial Number,Owner" -Encoding Unicode

    foreach ($CSV in $CSVtoRemove){
        $ownerCSV = @()

        $pathCSV = get-childitem ($pathCsvFiles + "\" + $CSV.FileName)
        $ownerCSV = $CSV.CreatedBy
        $Entries = Import-Csv -path $pathCSV
        $totalDevices += Import-Csv -path $pathCSV | Measure-Object | Select-Object -expand count

        foreach ($Entry in $Entries){
            $serial = $entry.'Device Serial Number'
            "{0},{1}" -f $serial,$ownerCSV | Add-Content -Path $CheckedCombinedOutput -Encoding Unicode
            Write-Log -LogOutput ("$serial add to the remove list.") -Path $LogFile     
        }     
    }

    Write-Log -LogOutput ("End first stage: download and prepare files.") -Path $LogFile
    ######### End first stage: download and prepare files #########

    ######### Start second stage: remove device from Autopilot #########
    Write-Log -LogOutput ("Start second stage: remove device from Autopilot.") -Path $LogFile

    $devices = @()
    $devices = Import-CSV $checkedCombinedOutput
    
    foreach ($device in $devices){
        $deviceOwner = @()
        $groups = @()
        $gcCountry = @()
        $gcEntity = @()
        $adminGroup = @()
        $pawGroup = @()

        # Check if correctDevice already exist in Autopilot
        $serial = $device.'Device Serial Number'
        $deviceOwner = $device.Owner
        $AutopilotDevices = $APDevices | Where-Object {$_.SerialNumber -eq $serial}

        # Create obj that can be used by each block to add the error code
        $obj = new-object psobject -Property @{
            SerialNumber = $serial
            Owner = $deviceOwner
        }

        # Check if device exist before going further
        if (-not(!$AutopilotDevices)){
            # It is possible that there are multiple Autopilot devices with the same serial due to motherboard replacements
            foreach ($AutopilotDevice in $AutopilotDevices){

                # Get owner group memberships that match groups mentioned in $valuesToLookFor
                $Groups = (Get-AADUserGroupMembership -upn $deviceOwner | Where-Object DisplayName -Match ($valuesToLookFor -join "|")).DisplayName

                # Strip groups to check permissions if in $valuesToLookFor add to $adminGroup
                foreach ($Group in $Groups){
                    if (($Group -notlike "*All") `
                    -and ($Group -notlike "*PAW")){
                        $g = "{0}-{1}-{2}-{3}" -f $Group.Split('-')
                        $gc = $g.Split("-")[-2] # Get country group
                        $ge = $g.Split("-")[-1] # Get entity group
                        
                        $gcCountry += $gc
                        $gcEntity += $ge
                    }
                    else {
                        if($Group -like "*All"){$adminGroup += $Group}
                        if($Group -like "*PAW"){$pawGroup += $Group}
                    }
                }

                if($($AutopilotDevice.GroupTag) -notin $cLabel){
                    $at = $AutopilotDevice.GroupTag.Replace("STOLEN_","")
                    $tc = $at.Split("-")[-2] # Get country tag
                    $te = $at.Split("-")[-1] # Get entity tag
                    $obj | Add-Member -Name 'groupTag' -Type NoteProperty -Value $at
                }
                else {
                    $p = $AutopilotDevice.GroupTag.Replace("STOLEN_","")
                    $obj | Add-Member -Name 'groupTag' -Type NoteProperty -Value $p
                }                    

                # When owner has permissions on grouptag or grouptag is emtpy go further
                if (($tc -in $gcCountry) -and ($te -in $gcEntity) `
                -or ((-not(!$p)) -and (-not(!$pawGroup))) `
                -or (-not(!$adminGroup)) `
                -or ($null -eq $AutopilotDevice.groupTag)){
                    
                    # if managedDeviceId cannot be found it's not active in Intune go further               
                    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($AutopilotDevice.managedDeviceId)"
                    try {
                        $md = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get -ErrorAction SilentlyContinue).id
                    } catch {
                        $md = $null
                    }

                    if (-not($md)){
                        Remove-AutoPilotDevice -id $AutopilotDevice.id

                        $successDevice += $device
                        Write-Log -LogOutput ("$($AutopilotDevice.serialNumber) with grouptag $($AutopilotDevice.groupTag) removed from Autopilot.") -Path $LogFile
                    }
                    else {
                        $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(Device is active in Intune)" 
                        $badDevices += $obj
                        
                        Write-Log -LogOutput ("$serial cannot be removed is active in Intune with ID: $($AutopilotDevice.managedDeviceId).") -Path $LogFile

                        # Device only removed from removed list when device is still active in Intune
                        (Get-Content $checkedCombinedOutput) | Where-Object {$_ -notmatch $Serial} | Set-Content $checkedCombinedOutput -Encoding Unicode
                        Write-Log -LogOutput ("$Serial removed from the removed devices list.") -Path $LogFile
                    }
                }
                else {
                    $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(No permissions on current grouptag)"
                    $badDevices += $obj
                    
                    Write-Log -LogOutput ("$serial no permissions $deviceOwner on $at.") -Path $LogFile

                    # Device owner does not have permissions on grouptag
                    (Get-Content $checkedCombinedOutput) | Where-Object {$_ -notmatch $Serial} | Set-Content $checkedCombinedOutput -Encoding Unicode
                    Write-Log -LogOutput ("$serial removed from the removed devices list.") -Path $LogFile
                }
            }
        }
        else {
            $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(Device not found)"
            $badDevices += $obj
            
            Write-Log -LogOutput ("$Serial not found in Autopilot.") -Path $LogFile

            # Device not found in Autopilot
            (Get-Content $checkedCombinedOutput) | Where-Object {$_ -notmatch $Serial} | Set-Content $checkedCombinedOutput -Encoding Unicode
            Write-Log -LogOutput ("$serial removed from the removed devices list.") -Path $LogFile
        }
    }

    Write-Log -LogOutput ("End second stage: remove device from Autopilot.") -Path $LogFile
    ######### End second stage: remove device from Autopilot #########

    ######### Start third stage: send error mail, uploading and cleaning files #########
    Write-Log -LogOutput ("Start third stage: send error mail, uploading and cleaning files.") -Path $LogFile

    # Export removed devices to CSV
    $devices = @()
    $devices = Import-CSV $checkedCombinedOutput
    if($null -ne $devices){
        $devices | Select-Object 'Device Serial Number', 'Owner' | Export-Csv -Path $DevicesDeletedPath -Delimiter "," -NoTypeInformation
        $dummy = Add-PnPFile -Path $DevicesDeletedPath -Folder $deletedFolderName
        Write-Log -LogOutput ("Removed devices found creating log file and upload to SharePoint.") -Path $LogFile
    }
    else {
        Write-Log -LogOutput ("No devices are removed due to errors check Autopilot-Import-Errors.csv.") -Path $LogFile
    }
}
else {
    Write-log -LogOutput ("No valid CSV files found in remove folder.") -Path $LogFile 
}    

# Total number of devices being processed
Write-Output "$totalDevices devices being processed."
Write-Log -LogOutput ("$totalDevices devices being processed.") -Path $LogFile

# Devices that are removed successfully
Write-Output "$($successDevice.Count) devices that are removed successfully."
Write-Log -LogOutput ("$($successDevice.Count) devices that are removed successfully.") -Path $LogFile

# Devices that are not removed due to errors
Write-Output "$($badDevices.Count) devices with errors."
Write-Log -LogOutput ("$($badDevices.Count) devices with errors.") -Path $LogFile

# Set the style for the email
$CSS = @"
<caption>Error(s) occured during Autopilot removal process</caption>
<style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
}
th, td {
  padding: 5px;
}
th {
  text-align: left;
}
</style>
"@

# Export Autopilot removal errors upload to SharePoint and send mail to CSV owner
if($badDevices.Count -ne 0){

    $u = ($badDevices | Select-Object Owner -Unique)
    $Users = $u.Owner
    
    foreach ($User in $Users){
        $UserDevices = $badDevices | Where-Object {$_.Owner -eq $User}
        $Body = @() 

        foreach ($UserDevice in $UserDevices){           
            $obj = new-object psobject -Property @{
                SerialNumber = $UserDevice.SerialNumber
                GroupTag = $UserDevice.groupTag
                Owner = $UserDevice.Owner
                Error = $UserDevice.Error
            }

            $Body += $obj | Select-Object SerialNumber, GroupTag, Owner, Error
        }        
        # Format content to be able to use it as body for send-mail
        $Content = $Body | ConvertTo-Html | Out-String
        $Content = $Content.Trim('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">')
        $Content = $Content.Replace('<html xmlns="http://www.w3.org/1999/xhtml">', '<html>')
        $Content = $content.Replace("<title>HTML TABLE</title>", $CSS)

        $UserMail = (Get-AADUserMail -UserPrincipalName $User).mail
              
        if ($null -ne $UserMail){          
            $Subject = "Error occured during Autopilot removal for $User"
            
            $Recipients = @(
                $($UserMail)
            )
            
            Send-Mail -Recipients $Recipients -Subject $Subject -Body $Content -MailSender $MailSender
            Write-Log -LogOutput ("Send error mail to $UserMail") -Path $LogFile
        } 
        else {
            Write-Log -LogOutput ("No emailaddress found for $User") -Path $LogFile
        }
    }
        
	$badDevices | Select-Object SerialNumber, GroupTag, Owner, Error  | Export-Csv -Path $RemovedErrorsPath -Delimiter "," -NoTypeInformation   
	$dummy = Add-PnPFile -Path $RemovedErrorsPath -Folder $errorsFolderName
	Write-Log -LogOutput ("Removal errors found creating log file and upload to SharePoint.") -Path $LogFile
}
Else {
    Write-Log -LogOutput ("No bad devices found.") -Path $LogFile
}

######### End third stage: send error mail, uploading and cleaning files #########
Write-Log -LogOutput ("End third stage: send error mail, uploading and cleaning files.") -Path $LogFile

# Upload log file
$dummy = Add-PnPFile -Path $LogFile -Folder $LogFolderName

# Clean remaining files from hybrid worker temp folder
$ItemsToRemove = @($CheckedCombinedOutput,$DevicesDeletedPath,$RemovedErrorsPath,$LogFile)
foreach ($Item in $ItemsToRemove){
    try {
        Remove-item $Item -ErrorAction SilentlyContinue
    } catch {
        #Item already removed or cannot be found
    }
}

foreach ($CSV in $CSVtoRemove) {Remove-item ($pathCsvFiles + "\" + $CSV.FileName) -ErrorAction SilentlyContinue}