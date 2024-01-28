#=============================================================================================================================
#
# Script Name:     ConfigureAppInstallerDetect.ps1
# Description:     This detection script will check the configured Winget (AppInstaller) policies on a local machine.
#   
# Notes      :     Configure the Winget (App Installer policies) to only allow to install apps from Microsoft trusted store.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

$EC = @()
$ScriptName = 'ConfigureAppInstaller_Detect'
$Log_File = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$ScriptName.log"
$Target = 'HKLM:\Software\Policies\Microsoft\Windows\AppInstaller'

[hashtable]$RegKeys = @{
  "EnableAllowedSources" = 0
  "EnableAppInstaller" = 1
  "EnableDefaultSource" = 0
  "EnableMicrosoftStoreSource" = 1
  "EnableAdditionalSources" = 0
  "EnableSettings" = 0
 }

#### Define Write_Log function ####
Function Write_Log
	{
	param(
	$Message_Type, 
	$Message
	)
		$MyDate = "[{0:dd/MM/yyyy} {0:HH:mm:ss}]" -f (Get-Date)  
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"  
	} 

If (Test-Path -Path $Log_File) {
    If ((Get-Item -Path $Log_File).Length -gt '100000') {Remove-Item -Path $Log_File -Force}
}

Write_Log -Message_Type "INFO" -Message "############################ $ScriptName DETECT ############################"

#Detect
If (Test-Path -Path $Target) {

    [hashtable]$GetRegKeys = @{}
    Get-Item $Target |
        Select-Object -ExpandProperty Property |
        ForEach-Object {
            $GetRegKeys.Add($_, (Get-ItemProperty -Path $Target -Name $_).$_)
    }

    # Check if hashtables are the same
    $RegKeys.GetEnumerator() | Select-Object Key, @{ n='Value'; e={$GetRegKeys[$_.Name]}}
    $ComparedRegKeys = $RegKeys.GetEnumerator() | ForEach-Object{[PSCustomObject]@{aKey=$_.Key;aValue=$_.Value;bValue=$GetRegKeys[$_.Name]}}

    $Count = 0
    # when aValue and bValue are the same
    foreach ($Key in $ComparedRegKeys){
        if ($Key.aValue -eq $Key.bValue){
            $Count += 1
        }
    }
     	
	If ($Count -eq $RegKeys.Count) {
		Write_Log -Message_Type "INFO" -Message "All values are correct";$EC += 0}
	ElseIf ($Count -ne $RegKeys.Count) {
		Write_Log -Message_Type "ERROR" -Message "Mismatch between registry keys and values"; $EC += 1}

} Else { 
    Write_Log -Message_Type "ERROR" -Message "Path [$Target] not exist" -ForegroundColor Red
    $EC += 1
}

$ExitCode = ($EC | Measure-Object -Sum).Sum
Write_Log -Message_Type "INFO" -Message "Exit code : $ExitCode"
Exit $ExitCode