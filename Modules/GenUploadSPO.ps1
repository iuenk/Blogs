#=============================================================================================================================
#
# Script Name:     GenUploadSPO.ps1
# Description:     Upload report to specified SharePoint site and folder.
#   
# Notes      :     Import this module and upload report to specified SharePoint site and folder.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

Function Upload-SPO{

	param(
		[Parameter(Mandatory=$true)]$Filename,
		[Parameter(Mandatory=$true)]$SiteURL,
		[Parameter(Mandatory=$true)]$DestinationPath
	)

	#Import PnP
	Import-Module PnP.Powershell
	#Import-Module SharepointPnPPowershellOnline

	#File to Upload to SharePoint
	$SourceFilePath = $Filename
	
	#Get Credentials to connect
	$Cred = Get-AutomationPSCredential -Name "AutomationCreds"
	
	#Connect to PnP Online
	Connect-PnPOnline -Url $SiteURL -Credentials $Cred -WarningAction Ignore
		
	#powershell pnp to upload file to sharepoint online
    #The $Dummy variable before Add-pnpfile can be necessary due to a bug see https://github.com/pnp/PnP-PowerShell/issues/918.
	$dummy = Add-PnPFile -Path $SourceFilePath -Folder $DestinationPath | Out-Null
}