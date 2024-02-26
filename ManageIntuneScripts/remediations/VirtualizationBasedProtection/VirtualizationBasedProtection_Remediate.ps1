#=============================================================================================================================
#
# Script Name:     VirtualizationBasedProtection_Remediate.ps1
# Description:     Enable virtualization-based protection of code integrity.
# Notes      :           
#
# Created by :     Ivo Uenk
# Date       :     02-08-2023
# Version    :     1.0
#=============================================================================================================================
$EC = 0
$ScriptName = 'VirtualizationBasedProtection_Remediate'
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

Write_Log -Message_Type "INFO" -Message "############################ $ScriptName REMEDIATE ############################"

try {
	# DeviceGuard
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -PropertyType "DWORD" -Value 1 -Force 
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "RequirePlatformSecurityFeatures" -PropertyType "DWORD" -Value 1 -Force 
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "Locked" -PropertyType "DWORD" -Value 1 -Force
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "Unlocked" -PropertyType "DWORD" -Value 0 -Force  
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "HypervisorEnforcedCodeIntegrity" -PropertyType "DWORD" -Value 1 -Force 

	# HypervisorEnforcedCodeIntegrity
	if (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity")){ 
		New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force 
	} 
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -PropertyType "DWORD" -Value 1 -Force 
	New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Locked" -PropertyType "DWORD" -Value 1 -Force 
	
	# LsaCfgFlags
	New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\LSA" -Name "LsaCfgFlags" -PropertyType "DWORD" -Value 1 -Force 

    Write_Log -Message_Type "INFO" -Message "Virtualization-based security (VBS) is set"
    $EC += 0
}
catch {
    Write_Log -Message_Type "ERROR" -Message "Failed to set virtualization-based security (VBS)" -ForegroundColor Red
    $EC += 1
}

# this is going to be true or false
if($EC -eq 0){
    $ExitCode = 0
}
else {
    $ExitCode = 1
}

Write_Log -Message_Type "INFO" -Message "Exit code : $ExitCode"
exit $ExitCode