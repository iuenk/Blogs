#=============================================================================================================================
#
# Script Name:     VirtualizationBasedProtection_Detect.ps1
# Description:     Enable virtualization-based protection of code integrity.
# Notes      :           
#
# Created by :     Ivo Uenk
# Date       :     02-08-2023
# Version    :     1.0
#=============================================================================================================================
$EC = 0
$ScriptName = 'VirtualizationBasedProtection_Detect'
$Log_File = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$ScriptName.log"

#### Define Write_Log function ####
function Write_Log
	{
	param(
	$Message_Type, 
	$Message
	)
		$MyDate = "[{0:dd/MM/yyyy} {0:HH:mm:ss}]" -f (Get-Date)  
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"  
	} 

if (Test-Path -Path $Log_File){
    if ((Get-Item -Path $Log_File).Length -gt '100000') {Remove-Item -Path $Log_File -Force}
}

Write_Log -Message_Type "INFO" -Message "############################ $ScriptName DETECT ############################"

[hashtable]$RegKeys = @{
    "EnableVirtualizationBasedSecurity" = 1
    "RequirePlatformSecurityFeatures" = 1
    "Locked" = 1
    "Unlocked" = 0
    "HypervisorEnforcedCodeIntegrity" = 1
}

$Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'

if (Test-Path -Path $Target){

    [hashtable]$GetRegKeys = @{}
    Get-Item $Target |
        Select-Object -ExpandProperty Property |
        ForEach-Object {
            $GetRegKeys.Add($_, (Get-ItemProperty -Path $Target -Name $_).$_)
    }

    $RegKeys.GetEnumerator() | Select-Object Key, @{ n='Value'; e={$GetRegKeys[$_.Name]}}
    $ComparedRegKeys = $RegKeys.GetEnumerator() | ForEach-Object{[PSCustomObject]@{aKey=$_.Key;aValue=$_.Value;bValue=$GetRegKeys[$_.Name]}}

    $Count = 0
    foreach ($Key in $ComparedRegKeys){
        if ($Key.aValue -eq $Key.bValue){
            $Count += 1
        }
    }
     	
	if ($Count -eq $RegKeys.count){
		Write_Log -Message_Type "INFO" -Message "All values are correct";$EC += 0}
	elseif ($Count -ne $RegKeys.count){
		Write_Log -Message_Type "ERROR" -Message "Mismatch between registry keys and values"; $EC += 1}

} else { 
    Write_Log -Message_Type "ERROR" -Message "Path [$Target] not exist"; $EC += 1}

[hashtable]$RegKeys = @{
    "Enabled" = 1
    "Locked" = 1
}

$Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'

if (Test-Path -Path $Target){

    [hashtable]$GetRegKeys = @{}
    Get-Item $Target |
        Select-Object -ExpandProperty Property |
        ForEach-Object {
            $GetRegKeys.Add($_, (Get-ItemProperty -Path $Target -Name $_).$_)
    }

    $RegKeys.GetEnumerator() | Select-Object Key, @{ n='Value'; e={$GetRegKeys[$_.Name]}}
    $ComparedRegKeys = $RegKeys.GetEnumerator() | ForEach-Object{[PSCustomObject]@{aKey=$_.Key;aValue=$_.Value;bValue=$GetRegKeys[$_.Name]}}

    $Count = 0
    foreach ($Key in $ComparedRegKeys){
        if ($Key.aValue -eq $Key.bValue){
            $Count += 1
        }
    }
     	
	if ($Count -eq $RegKeys.count){
		Write_Log -Message_Type "INFO" -Message "All values are correct";$EC += 0}
	elseif ($Count -ne $RegKeys.count){
		Write_Log -Message_Type "ERROR" -Message "Mismatch between registry keys and values"; $EC += 1}

} else { 
    Write_Log -Message_Type "ERROR" -Message "Path [$Target] not exist";$EC += 1}

$CorrectRegValue = '1'
$RegKey = 'LsaCfgFlags'
$Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

if (Test-Path -Path $Target){

    $RegValue = (Get-Item -Path $Target).GetValue($RegKey)
		
	if ($RegValue -eq $CorrectRegValue){
		Write_Log -Message_Type "INFO" -Message "Correct value : [$RegKey : $RegValue]";$EC += 0}
	elseif ($null -eq $RegValue ){
		Write_Log -Message_Type "ERROR" -Message "[$RegKey] not exist"; $EC += 1}
	else {Write_Log -Message_Type "ERROR" -Message "Wrong value : [$RegKey : $RegValue]";$EC += 1}

} else { 
    Write_Log -Message_Type "ERROR" -Message "Path [$Target] not exist"; $EC += 1}

# this is going to be true or false
if($EC -eq 0){
    $ExitCode = 0
}
else {
    $ExitCode = 1
}
    
Write_Log -Message_Type "INFO" -Message "Exit code : $ExitCode"
exit $ExitCode