. .\GenMSALToken.ps1
. .\GenMail.ps1

#Requires -Module  PnP.PowerShell, AutopilotUtility

<#PSScriptInfo
.VERSION 2.3
.AUTHOR Ivo Uenk
.RELEASENOTES

#>
<#
.SYNOPSIS
Get Autopilot CSV's from SharePoint and import in Autopilot based on specified criteria.
.DESCRIPTION
Get Autopilot CSV's from SharePoint and import in Autopilot based on specified criteria.
Check URL's if Autopilot service is running otherwise this script will run till timeout see https://social.technet.microsoft.com/Forums/en-US/6f175627-a568-43d4-b518-26e6d049d659/something-went-wrong-oobeaadv10?forum=microsoftintuneprod.
The hardware decryption will be done by the ConvertFrom-AutopilotHash function that's in the module https://www.powershellgallery.com/packages/AutopilotUtility/1.0.
The $Dummy variable before Add-pnpfile can be necessary due to a bug see https://github.com/pnp/PnP-PowerShell/issues/918.
It will update the grouptag when a device with the same serial already exist in Autopilot and the owner does have permission on using that grouptag.
.NOTES
  Version:        2.3
  Author:         Ivo Uenk
  Creation Date:  2023-09-13
  Purpose/Change: Production
#>

# Variables
$PathCsvFiles = "$env:TEMP"
$checkedCombinedOutput = "$pathCsvFiles\checkedcombinedoutput.csv"
$SiteURL = Get-AutomationVariable -Name "SPOAutopilotSiteURL"
$ShortSiteURL = "/" + $SiteURL.split("/",4)[-1]
$importAutopilotDeviceFolderPath = Get-AutomationVariable -Name "SPOimportAutopilotDeviceFolderPath"
$Uris = "login.live.com", "login.microsoftonline.com", "portal.manage.microsoft.com", "EnterpriseEnrollment.manage.microsoft.com", "EnterpriseEnrollment-s.manage.microsoft.com"

$importFolderPath = $ShortSiteURL + $importAutopilotDeviceFolderPath + "/Import"
$sourcesFolderPath = $ShortSiteURL + $importAutopilotDeviceFolderPath + "/Sources"
$importedFolderPath = $ShortSiteURL + $importAutopilotDeviceFolderPath + "/Imported"
$errorsFolderPath = $ShortSiteURL + $importAutopilotDeviceFolderPath + "/Errors"
$LogFolderPath = $ShortSiteURL + $importAutopilotDeviceFolderPath + "/Logging"
$importFolderSiteRelativeUrl = $importAutopilotDeviceFolderPath + "/Import"
$DevicesImportedPath = $PathCsvFiles + "\" + "Autopilot-Import" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".csv"
$ImportErrorsPath = $PathCsvFiles + "\" + "Autopilot-Import-Errors" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".csv"
$LogFile = $PathCsvFiles + "\" + "Autopilot-Actions" + "-" + ((Get-Date).ToString("dd-MM-yyyy-HHmm")) + ".log"
$MailSender = Get-AutomationVariable -Name "MailSender"

# Declare checklist variables
$Model = Get-AutomationVariable -Name "cModel"
$cModel = $Model.Split(",")
$Label = Get-AutomationVariable -Name "cLabel"
$cLabel = $Label.Split(",")
$Country = Get-AutomationVariable -Name "cCountry"
$cCountry = $Country.Split(",")
$Entity = Get-AutomationVariable -Name "cEntity"
$cEntity = $Entity.Split(",")

# Credentials
try {
    $AutomationCredential = Get-AutomationPSCredential -Name "AutomationCreds"
    $userName = $AutomationCredential.UserName  
    $securePassword = $AutomationCredential.Password
    $psCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $securePassword 

    Connect-PnPOnline -Url $SiteURL -Credentials $psCredential
} 
catch {
    Write-output "Cannot connect to Microsoft services"
    break
}

# Check if AutopilotUtility module is installed
if (-not(Get-Module -ListAvailable -Name AutopilotUtility)){
    Write-output "Module AutopilotUtility does not exist"
    break
}

######### Functions #########
function Update-GroupTag(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $id,
    [Parameter(Mandatory=$true)] $groupTag

)
    
    # Defining Variables
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/windowsAutopilotDeviceIdentities"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$id/UpdateDeviceProperties"

    $json = @"
{
    "groupTag": "$groupTag"
}
"@

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post -Body $json -ContentType "application/json"
        if ($id) {
            $response
        }
        else {
            $response.Value
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
    
function Get-AutoPilotImportedDevice(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$false)] $id
)
    # Defining Variables
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/importedWindowsAutopilotDeviceIdentities"

    if ($id) {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$id"
    }
    else {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
    }
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
        if ($id) {
            $response
        }
        else {
            $response.Value
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

function Add-AutoPilotImportedDevice(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $serialNumber,
    [Parameter(Mandatory=$true)] $hardwareIdentifier,
    [Parameter(Mandatory=$true)] $groupTag,
    [Parameter(Mandatory=$false)] $orderIdentifier = ""
)  
    # Defining Variables
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/importedWindowsAutopilotDeviceIdentities"

    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
    $json = @"
{
    "@odata.type": "#microsoft.graph.importedWindowsAutopilotDeviceIdentity",
    "orderIdentifier": "$orderIdentifier",
    "serialNumber": "$serialNumber",
    "groupTag": "$groupTag",
    "productKey": "",
    "hardwareIdentifier": "$hardwareIdentifier",
    "state": {
        "@odata.type": "microsoft.graph.importedWindowsAutopilotDeviceIdentityState",
        "deviceImportStatus": "pending",
        "deviceRegistrationId": "",
        "deviceErrorCode": 0,
        "deviceErrorName": ""
    }
}
"@

    try {
        Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post -Body $json -ContentType "application/json"
    }
    catch {            
        # If already exists Invoke-RestMethod update for example group tag
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

function Remove-AutoPilotImportedDevice(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $id
)
    # Defining Variables
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/importedWindowsAutopilotDeviceIdentities"    
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

function Import-AutoPilotCSV(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $csvFile,
    [Parameter(Mandatory=$true)] $LogFile,
    [Parameter(Mandatory=$false)] $orderIdentifier = ""
)
        
    # When script fails due to technical issues Autopilot service old entries will not be removed and script wil hang
    $deviceStatusesInitial = Get-AutoPilotImportedDevice
    $deviceCountInitial = $deviceStatusesInitial.Length
    if ($deviceCountInitial -gt 0) {
        Write-Log -LogOutput ("Previous cleanup didn't work, remove old entries before going further") -Path $LogFile
        $deviceStatusesInitial | ForEach-Object {
        Remove-AutoPilotImportedDevice -id $_.id
        }
    }
    # Read CSV and process each device
    $devices = Import-CSV $csvFile

    foreach ($device in $devices) {
    $Serial = $device.'Device Serial Number'

    Add-AutoPilotImportedDevice -serialNumber $Serial -hardwareIdentifier $device.'Hardware Hash' -orderIdentifier $orderIdentifier -groupTag $device.'Group Tag'
    Write-Log -LogOutput ("$Serial importing device.") -Path $LogFile
    }
    # Give the Autopilot service some time to process 
    Start-Sleep 60

    # While we could keep a list of all the IDs that we added and then check each one, it is easier to just loop through all of them
    $processingCount = 1
    while ($processingCount -gt 0)
    {
        $deviceStatuses = Get-AutoPilotImportedDevice

        # Check to see if any devices are still processing
        $processingCount = 0
        foreach ($device in $deviceStatuses){
            if ($($device.state.deviceImportStatus).ToLower() -eq "unknown" -or $($device.state.deviceImportStatus).ToLower() -eq "pending") {
                $processingCount = $processingCount + 1
            }
        }
        Write-Output "Waiting for $processingCount of $($deviceStatuses.Count)"

        # Still processing sleep before trying again
        if ($processingCount -gt 0){
            Start-Sleep 20
        }
    }
    # Generate some statistics for reporting
    ForEach ($deviceStatus in $deviceStatuses) {
    $Device = $deviceStatus.serialNumber

        if (($($deviceStatus.state.deviceImportStatus).ToLower() -eq 'success' -or $($deviceStatus.state.deviceImportStatus).ToLower() -eq 'complete')){
            $global:successDevice += $device
            Write-Log -LogOutput ("$Device import completed.") -Path $LogFile

        } elseif ($($deviceStatus.state.deviceImportStatus).ToLower() -eq 'error') {
            $global:errorDevice += $Device

            # Device is registered to another tenant
            Write-Log -LogOutput ("$Device import failed.") -Path $LogFile

            if ($($deviceStatus.state.deviceErrorCode) -eq 808) {
                $global:softErrorDeviceAssignedOtherTenant += $Device
                Write-Log -LogOutput ("$Device is assigned to another tenant.") -Path $LogFile
            }
        }
    }
    # Display the statuses
    $deviceStatuses | ForEach-Object {
        Write-Output "Serial number $($_.serialNumber): $($_.groupTag), $($_.state.deviceImportStatus), $($_.state.deviceErrorCode), $($_.state.deviceErrorName)"
    }

    # If device serialnumber already exist due to mainboard replacement process it will result in both complete and error
    $global:successDevice = $global:successDevice | Where-Object {$_ -notin $global:errorDevice}

    # Cleanup the imported device records
    $deviceStatuses | ForEach-Object {
        Remove-AutoPilotImportedDevice -id $_.id
    }
}

function Invoke-AutopilotSync(){
[cmdletbinding()]
param
(
)
    # Defining Variables
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/windowsAutopilotSettings/sync"

    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post
        $response.Value
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

function Get-HardwareInfo(){
Param(
    [Parameter(Mandatory=$true)]
    [string]$csvFile,
    [Parameter(Mandatory=$true)]
    [string]$LogFile
)

    # Read CSV and process each device
    $devices = Import-CSV $csvFile

    $global:AutopilotImports = @()

    Foreach ($Device in $Devices){
        $Serial = $($device.'Device Serial Number')

        try {
            $h = ConvertFrom-AutopilotHash -Hash $device.'Hardware Hash'
            
            # Necessary because otherwhise it cannot be handled by unicode (remove special characters)
            $SmbiosSerial = $h.SmbiosSerial -replace '[^\p{L}\p{Nd}]', ''

            $obj = new-object psobject -Property @{
                SerialNumber = $SmbiosSerial
                WindowsProductID = $device.'Windows Product ID'
                Hash = $device.'Hardware Hash'
                Model = $h.SmbiosProductName
                GroupTag = $device.'Group Tag'
                TPMVersion = $h.TpmVersion
                Owner = $device.'Owner'
            }

            if ($SmbiosSerial -eq $Serial){
                $global:AutopilotImports += $obj
                Write-Log -LogOutput ("$Serial hardware report ran successfully.") -Path $LogFile
            }
            else {
                $obj = new-object psobject -Property @{
                    SerialNumber = $SmbiosSerial
                    WindowsProductID = $device.'Windows Product ID'
                    Hash = $device.'Hardware Hash'
                    Model = $h.SmbiosProductName
                    groupTag = $Device.'Group Tag'
                    TPMVersion = $h.TpmVersion
                    Owner = $device.'Owner'
                    Error = "Serial mismatch"
                }
                $global:badDevices += $obj
                (Get-Content $csvFile) | Where-Object {$_ -notmatch $Serial} | Set-Content $csvFile -Encoding Unicode
                Write-Log -LogOutput ("$Serial error does not match with serial in hardware hash $SmbiosSerial removed from import list.") -Path $LogFile
            }
        }       
        catch {
            $obj = new-object psobject -Property @{
                SerialNumber = $Serial
                WindowsProductID = $device.'Windows Product ID'
                Hash = $device.'Hardware Hash'
                Model = "Model not checked"
                groupTag = $Device.'Group Tag'
                TPMVersion = "TPM not checked"
                Owner = $device.'Owner'
                Error = "Bad hardware hash"
            }
            $global:badDevices += $obj
            (Get-Content $csvFile) | Where-Object {$_ -notmatch $Serial} | Set-Content $csvFile -Encoding Unicode
            Write-Log -LogOutput ("$Serial error bad hardware hash removed from import list.") -Path $LogFile
        }
    }
}
######### End Functions #########

# Get all files from ImportAutopilotDevice folder stop if no files are found
$folderItems = Get-PnPFolderItem -FolderSiteRelativeUrl $importFolderSiteRelativeUrl -ItemType File
if (!$folderItems) {
    Write-Output "No file(s) found in the Autopilot import folder"
    break
}

# Check if Autopilot service is running break script if an URL is not reachable
foreach ($Uri in $Uris){
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
$correctDevices = @()
$global:badDevices = @()
$global:successDevice = @()
$global:updatedDevice = @()
$global:errorDevice = @()
$global:softErrorDeviceAssignedOtherTenant = @()
$global:valuesToLookFor = @(
    'SG_CMW_Autopilot'
)

######### Start first stage: download and prepare files #########
Write-Log -LogOutput ("Start first stage: download and prepare files.") -Path $LogFile

# Remove previous files if not cleanup up properly
Get-ChildItem -Path $PathCsvFiles | Where-Object {$_.Name -like "checkedcombinedoutput*"} | Remove-Item
Get-ChildItem -Path $PathCsvFiles | Where-Object {$_.Name -like "Autopilot*"} | Remove-Item

# Start downloading necessary files from SharePoint
$CSVtoImport = @()

# Download CSV files from SharePoint
foreach($item in $folderItems){

    # Get filename and createdby
    $FileName = $item.Name
    $FileRelativeURL = ($importFolderPath + "/" + $FileName)
    $File = Get-PnPFile -Url "$FileRelativeURL" -AsListItem
    $targetLibraryUrl = $sourcesFolderPath + '/' + $FileName

    # If file is CSV continue
    if($FileName -like "*.csv"){

        $obj = new-object psobject -Property @{
            FileName = $File["FileLeafRef"]
            CreatedBy = $File["Created_x0020_By"].Split("|",3)[-1]
        }
        $CSVtoImport += $obj

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

        # Remove spaces in header
        $a = Get-Content $PathCsvFile
        $a[0] = $a[0] -replace "Group Tag ", "Group Tag"
        $a | Set-Content $PathCsvFile
        Write-Log -LogOutput ("File $FileName checked for spaces.") -Path $LogFile
        
        # Move the file after being processed
        Move-PnPFile -SourceUrl $item.ServerRelativeUrl -TargetUrl $targetLibraryUrl -AllowSchemaMismatch -Force -Overwrite -AllowSmallerVersionLimitOnDestination
    }
    else {
        $obj = new-object psobject -Property @{
            SerialNumber = ""
            WindowsProductID = ""
            Hash = ""
            groupTag = ""
            model = ""
            TPMVersion = ""
            Owner = $($File["Created_x0020_By"].Split("|",3)[-1])
            Error = "($FileName bad file format)"
        }
        $global:badDevices += $obj
        Write-Log -LogOutput ("File $FileName not a valid CSV file.") -Path $LogFile

        # Move the file after being processed
        Move-PnPFile -SourceUrl $item.ServerRelativeUrl -TargetUrl $targetLibraryUrl -AllowSchemaMismatch -Force -Overwrite -AllowSmallerVersionLimitOnDestination
    }
}

Write-Log -LogOutput ("End first stage: download and prepare files.") -Path $LogFile
######### End first stage: download and prepare files #########

if(-not(!$CSVtoImport)){
    ######### Start second stage: check group tag permissions and update #########
    Write-Log -LogOutput ("Start second stage: check group tag permissions and update.") -Path $LogFile

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

    # Create CSV file that will be filled with devices that are eligible for import
    Set-Content -Path $CheckedCombinedOutput -Value "Device Serial Number,Windows Product ID,Hardware Hash,Group Tag,Owner" -Encoding Unicode

    foreach ($CSV in $CSVtoImport){
    $global:Groups = @()
    $global:ownerCSV = @()
    $global:gcCountry = @()
    $global:gcEntity = @()
    $global:adminGroup = @()

        # Get info from CSV files
        $pathCSV = get-childitem ($pathCsvFiles + "\" + $CSV.FileName)
        $global:ownerCSV = $CSV.CreatedBy
        $devices = Import-Csv -path $pathCSV 
        $totalDevices += Import-Csv -path $pathCSV | Measure-Object | Select-Object -expand count

        # Get owner group memberships that match groups mentioned in $global:valuesToLookFor
        $global:Groups = (Get-AADUserGroupMembership -upn $global:ownerCSV | Where-Object DisplayName -Match ($global:valuesToLookFor -join "|")).DisplayName

        # Strip groups to check permissions if in $global:valuesToLookFor add to $global:adminGroup
        foreach ($Group in $global:Groups){
            if ($Group -notlike "*All"){
                $g = "{0}_{1}_{2}_{3}_{4}" -f $Group.Split('_')
                $gc = $g.Split("_")[-2] # Get country group
                $ge = $g.Split("_")[-1] # Get entity group
                
                $global:gcCountry += $gc
                $global:gcEntity += $ge
            }
            else {
                $global:adminGroup += $Group
            }
        }

        # Check foreach device the group tag format and permissions
        foreach ($device in $devices){
            $Serial = $device.'Device Serial Number'

            # Create obj that can be used by each block to add the error code
            $obj = new-object psobject -Property @{
                SerialNumber = $Serial
                WindowsProductID = $device.'Windows Product ID'
                Hash = $device.'Hardware Hash'
                groupTag = $device.'Group Tag'
                model = "Model not checked"
                TPMVersion = "TPM not checked"
                Owner = $global:ownerCSV
            }

            # Check if group tag is found
            if(-not(!$device.'Group Tag')){
                $at = $($device.'Group Tag').Replace("STOLEN_","")
                $l = "{0}-{1}-{2}-{3}" -f $at.Split('-')
                $c = $at.Split("-")[-2] # Get country tag
                $e = $at.Split("-")[-1] # Get entity tag

                # Check if group tag is formatted correctly
                if (($l -in $cLabel) -and ($c -in $cCountry) -and ($e -in $cEntity)){

                    # Check if the owner has permissions on new group tag
                    if (($c -in $global:gcCountry) -and ($e -in $global:gcEntity) -or (-not(!$global:adminGroup))){
                        
                        # Check if device already exist in Autopilot if so try to update the group tag
                        $AutopilotDevices = $APDevices | Where-Object {$_.SerialNumber -eq $Serial}

                        if(-not(!$AutopilotDevices)){
                            # It is possible that there are multiple Autopilot devices with the same serial due to motherboard replacements
                            foreach ($AutopilotDevice in $AutopilotDevices){

                                # Check if user has permissions on $AutopilotDevice.groupTag to prevent hijacking device
                                $apt = $AutopilotDevice.groupTag
                                $aptc = $apt.Split("-")[-2] # Get country tag
                                $apte = $apt.Split("-")[-1] # Get entity tag

                                # Check if the owner has permissions on the current group tag
                                if (($aptc -in $global:gcCountry) -and ($apte -in $global:gcEntity) -or (-not(!$global:adminGroup))){
                            
                                    # Check if current group tag is different from new group tag
                                    if ($AutopilotDevice.groupTag -ne $($device.'Group Tag')){                              
                                        Update-GroupTag -id $AutopilotDevice.id -groupTag $($device.'Group Tag')
                                        Write-Log -LogOutput ("$Serial group tag from $($AutopilotDevice.groupTag) to $($device.'Group Tag').") -Path $LogFile
                                        $global:updatedDevice += $Serial
                                        
                                        Write-Log -LogOutput ("$Serial group tag updating process finished.") -Path $LogFile
                                    }    
                                    else {
                                        $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(Device already exist in same tenant)"         
                                        $global:badDevices += $obj

                                        Write-Log -LogOutput ("$Serial already exists in same tenant remove from import list.") -Path $LogFile
                                    }  
                                }
                                else {
                                    $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(No permissions on current grouptag)"
                                    $global:badDevices += $obj

                                    Write-Log -LogOutput ("$($device.'Device Serial Number') no permissions $global:ownerCSV on current group tag $($device.'Group Tag').") -Path $LogFile
                                }    
                            }

                        }
                        else {
                            Write-Log -LogOutput ("$Serial not found in Autopilot proceed with importing process.") -Path $LogFile

                            # Add devices to the CheckedCombinedOutput list that will be used during the whole process
                            "{0},{1},{2},{3},{4}" -f $Serial,$device.'Windows Product ID',$device.'Hardware Hash',$device.'Group Tag',$global:ownerCSV | Add-Content -Path $CheckedCombinedOutput -Encoding Unicode
                            Write-Log -LogOutput ("$Serial add to import list $global:ownerCSV has permission on $($device.'Group Tag').") -Path $LogFile
                        }
                    }
                    else {
                        $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(No permissions on new grouptag)"
                        $global:badDevices += $obj

                        Write-Log -LogOutput ("$($device.'Device Serial Number') no permissions $global:ownerCSV on new group tag $($device.'Group Tag').") -Path $LogFile
                    }
                }
                else {                
                    $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(Bad grouptag)"
                    $global:badDevices += $obj

                    Write-Log -LogOutput ("$Serial bad group tag remove from import list.") -Path $LogFile   
                }
            }
            else {
                $obj | Add-Member -Name 'Error' -Type NoteProperty -Value "(No grouptag)"
                $global:badDevices += $obj

                Write-Log -LogOutput ("$Serial error no group tag found remove from import list.") -Path $LogFile 
            }     
        }
    }

    Write-Log -LogOutput ("End second stage: check group tag permissions and update.") -Path $LogFile
    ######### End second stage: check group tag permissions and update #########

    $devices = @()
    $devices = Import-CSV $checkedCombinedOutput
    if(-not(!$devices)){
        ######### Start third stage: get hardware info and check if conditions are met #########
        Write-Log -LogOutput ("Start third stage: get hardware info and check if conditions are met.") -Path $LogFile

        Get-HardwareInfo -csvFile $CheckedCombinedOutput -LogFile $LogFile

        foreach ($AutopilotImport in $global:AutopilotImports){
            $Serial = $AutopilotImport.SerialNumber

            # Create obj that can be used by each block to add the error code
            $obj = new-object psobject -Property @{
                SerialNumber = $Serial
                WindowsProductID = $AutopilotImport.WindowsProductID
                Hash = $AutopilotImport.Hash
                groupTag = $AutopilotImport.GroupTag
                model = $AutopilotImport.Model
                TPMVersion = $AutopilotImport.TPMVersion
                Owner = $AutopilotImport.Owner
            }

            # Check if conditions are met (cin to make it case sensitive)
            if (($AutopilotImport.Model -cin $cModel) -and ($AutopilotImport.TPMVersion -like "*2.0*")){
                
                $correctDevices += $obj
                Write-Log -LogOutput ("$Serial conditions are met remain on import list.") -Path $LogFile
            } 
            else {
                $ErrorModel = if(-not($AutopilotImport.Model -cin $cModel)){"(Bad Model)"}
                $ErrorTMP = if($AutopilotImport.TPMVersion -notlike "*2.0*"){"(Bad TPM)"}

                $obj | Add-Member -Name 'Error' -Type NoteProperty -Value $ErrorModel$ErrorTMP
                $global:badDevices += $obj

                (Get-Content $checkedCombinedOutput) | Where-Object {$_ -notmatch $Serial} | Set-Content $checkedCombinedOutput -Encoding Unicode
                Write-Log -LogOutput ("$Serial error $ErrorModel$ErrorTMP removed from import list.") -Path $LogFile
            }
        }
                
        Write-Log -LogOutput ("End third stage: get hardware info and check if conditions are met.") -Path $LogFile
        ######### End third stage: get hardware info and check if conditions are met #########

        $devices = @()
        $devices = Import-CSV $checkedCombinedOutput
        if (-not(!$devices)){
            ######### Start fourth stage: importing checked devices in Autopilot #########
            Write-Log -LogOutput ("Start fourth stage: importing checked devices in Autopilot.") -Path $LogFile
            Import-AutoPilotCSV $CheckedCombinedOutput -LogFile $LogFile

            foreach ($AutopilotImport in $global:AutopilotImports){
            $Serial = $AutopilotImport.SerialNumber

                if ($Device -in $global:successDevice){
                    # Do nothing device already exist or is imported successfully
                } 
                elseif (($Serial -in $global:errorDevice) -or ($Serial -in $global:softErrorDeviceAssignedOtherTenant)){
                    $FatalError = if($Serial -notin $global:softErrorDeviceAssignedOtherTenant){"(Fatal error during import)"}
                    $ZtdDeviceAssignedToOtherTenant = if($Serial -in $global:softErrorDeviceAssignedOtherTenant){"(Device is assigned to another tenant)"}

                    $obj = new-object psobject -Property @{
                        SerialNumber = $Serial
                        WindowsProductID = $AutopilotImport.WindowsProductID
                        Hash = $AutopilotImport.Hash
                        groupTag = $AutopilotImport.GroupTag
                        model = $AutopilotImport.Model
                        TPMVersion = $AutopilotImport.TPMVersion
                        Owner = $AutopilotImport.Owner
                        Error = $FatalError+$ZtdDeviceAssignedToOtherTenant
                    }
                    $global:badDevices += $obj
                    (Get-Content $checkedCombinedOutput) | Where-Object {$_ -notmatch $Serial} | Set-Content $checkedCombinedOutput -Encoding Unicode
                    Write-Log -LogOutput ("$Serial error $FatalError$ZtdDeviceAssignedToOtherTenant removed from import list.") -Path $LogFile
                }
            }

            Write-Log -LogOutput ("End fourth stage: importing checked devices in Autopilot.") -Path $LogFile
            ######### End fourth stage: importing checked devices in Autopilot #########

            # Export imported devices to CSV
            $devices = @()
            $devices = Import-CSV $checkedCombinedOutput
            if(-not(!$devices)){
                # Trigger Intune sync to process changes faster
                Write-output "Triggering Sync to Intune."
                Write-Log -LogOutput ("Triggering sync to Intune after imports.") -Path $LogFile
                Invoke-AutopilotSync

                $devices | Select-Object 'Device Serial Number', 'Windows Product ID', 'Hardware Hash', 'Group Tag', 'Owner' | Export-Csv -Path $DevicesImportedPath -Delimiter "," -NoTypeInformation
                $dummy = Add-PnPFile -Path $DevicesImportedPath -Folder $importedFolderPath 
                Write-Log -LogOutput ("Device imports found creating log file and upload to SharePoint.") -Path $LogFile
            }
            else {
                Write-Log -LogOutput ("No devices are imported due to errors...") -Path $LogFile
            }
        }
        else {
            Write-Log -LogOutput ("Nothing to import all devices are removed from the list...") -Path $LogFile
        }
    }
    else {
        Write-Log -LogOutput ("Nothing to import all devices are removed from the list...") -Path $LogFile
    }
}
else {
    Write-log -LogOutput ("No valid CSV files found in import folder.") -Path $LogFile 
}

######### Start fifth stage: process logging and clean used files #########
Write-Log -LogOutput ("Start fifth stage: process logging and clean used files.") -Path $LogFile

# Total number of devices being processed
Write-Output "$totalDevices devices being processed."
Write-Log -LogOutput ("$totalDevices devices being processed.") -Path $LogFile

# Devices that are imported successfully
Write-Output "$($global:successDevice.Count) devices that are imported successfully."
Write-Log -LogOutput ("$($global:successDevice.Count) devices that are imported successfully.") -Path $LogFile

# Devices that are updated successfully
Write-Output "$($global:updatedDevice.Count) devices that are updated successfully."
Write-Log -LogOutput ("$($global:updatedDevice.Count) devices that are updated successfully.") -Path $LogFile

# Devices that are not imported or updated due to errors
Write-Output "$($global:badDevices.Count) devices with errors."
Write-Log -LogOutput ("$($global:badDevices.Count) devices with errors.") -Path $LogFile

# Set the style for the email
$CSS = @"
<caption>Error(s) occured during Autopilot import process</caption>
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

# Export Autopilot import errors upload to SharePoint and send mail to CSV owner
if($global:badDevices.Count -ne 0){

    $u = ($global:badDevices | Select-Object Owner -Unique)
    $Users = $u.Owner
    
    foreach ($User in $Users){
        $UserDevices = $global:badDevices | Where-Object {$_.Owner -eq $User}
        $Body = @() 

        foreach ($UserDevice in $UserDevices){
            try {$TPMVersion = $UserDevice.TPMVersion.Split('-')[1]}
            catch {$TPMVersion = $null}
            
            $obj = new-object psobject -Property @{
                SerialNumber = $UserDevice.SerialNumber
                Model = $UserDevice.model
                TPMVersion = $TPMVersion
                GroupTag = $UserDevice.groupTag
                Owner = $UserDevice.Owner
                Error = $UserDevice.Error
            }

            $Body += $obj | Select-Object SerialNumber, Model, TPMVersion, GroupTag, Owner, Error
        }        
        # Format content to be able to use it as body for send-mail
        $Content = $Body | ConvertTo-Html | Out-String
        $Content = $Content.Trim('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">')
        $Content = $Content.Replace('<html xmlns="http://www.w3.org/1999/xhtml">', '<html>')
        $Content = $content.Replace("<title>HTML TABLE</title>", $CSS)

        $UserMail = (Get-AADUserMail -UserPrincipalName $User).mail
              
        if ($null -ne $UserMail){          
            $Subject = "Error occured during Autopilot import for $User"
            
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

	$global:badDevices | Select-Object SerialNumber, WindowsProductID, Hash, Model, TPMVersion, GroupTag, Owner, Error  | Export-Csv -Path $ImportErrorsPath -Delimiter "," -NoTypeInformation   
	$dummy = Add-PnPFile -Path $ImportErrorsPath -Folder $errorsFolderPath
	Write-Log -LogOutput ("Import errors found creating log file and upload to $LogFolderPath.") -Path $LogFile
}
else {
    Write-Log -LogOutput ("No bad devices found.") -Path $LogFile
}
Write-Log -LogOutput ("End fifth stage: process logging and clean used files.") -Path $LogFile

# Upload log file
$dummy = Add-PnPFile -Path $LogFile -Folder $LogFolderPath

# Clean remaining files from hybrid worker temp folder
$ItemsToRemove = @($CheckedCombinedOutput,$DevicesImportedPath,$ImportErrorsPath,$LogFile)
foreach ($Item in $ItemsToRemove){
    try {
        Remove-item $Item -ErrorAction SilentlyContinue
    } catch {
        #Item already removed or cannot be found
    }
}

foreach ($CSV in $CSVtoImport) {Remove-item ($pathCsvFiles + "\" + $CSV.FileName) -ErrorAction SilentlyContinue}
######### End fifth stage: uploading and cleaning files #########