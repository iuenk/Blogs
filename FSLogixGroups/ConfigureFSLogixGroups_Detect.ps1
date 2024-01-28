#=============================================================================================================================
#
# Script Name:     ConfigureFSLogixGroups_Detect.ps1
# Description:     This remediation script will check all members of the Administrators group and add those to the FSLogix exclude list
#   
# Notes      :     It will add all the Global administrator and Azure AD joined device local administrator SID's
#                  Those are by default added to the Administrators group for Azure AD joined endpoints
#                  The FSLogix local groups are created by default on Windows 10/11 Enterprise multi-session images
#                  Multi-session images do not support adding local administrators by using custom configuration profile or using Account Protection in Intune      
#
# Created by :     Ivo Uenk
# Date       :     28-6-2023
# Version    :     1.0
#=============================================================================================================================
$EC = @()
$ScriptName = 'ConfigureFSLogixGroups_Detect'
$Log_File = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$ScriptName.log"

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

if(Test-Path -Path $Log_File){
    if((Get-Item -Path $Log_File).Length -gt '10000') {Remove-Item -Path $Log_File -Force}
}

Write_Log -Message_Type "INFO" -Message "############################ $ScriptName DETECT ############################"

# Get all members from the Administrators group 
$Administrators = @()
foreach($group in Get-LocalGroup -Name "Administrators"){
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path})

    foreach($group_member in $group_members){
        $Administrators += ($group_member.split('/'))[-1]
    }
}

# Get all members from the FSLogix Profile Include List group 
$ProfileIncludeList = @()
foreach($group in Get-LocalGroup -Name "FSLogix Profile Include List"){
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path})

    foreach($group_member in $group_members){
        $ProfileIncludeList += ($group_member.split('/'))[-1]
    }
}

# Get all members from the FSLogix Profile Exclude List group 
$ProfileExcludeList = @()
foreach($group in Get-LocalGroup -Name "FSLogix Profile Exclude List"){
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path})

    foreach($group_member in $group_members){
        $ProfileExcludeList += ($group_member.split('/'))[-1]
    }
}

# Get all members from the FSLogix ODFC Include List group 
$ODFCIncludeList = @()
foreach($group in Get-LocalGroup -Name "FSLogix ODFC Include List"){
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path})

    foreach($group_member in $group_members){
        $ODFCIncludeList += ($group_member.split('/'))[-1]
    }
}

# Get all members from the FSLogix ODFC Exclude List group 
$ODFCExcludeList = @()
foreach($group in Get-LocalGroup -Name "FSLogix ODFC Exclude List"){
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path})

    foreach($group_member in $group_members){
        $ODFCExcludeList += ($group_member.split('/'))[-1]
    } 
}

$ProfileExcludeListCount = 0
$ODFCExcludeListCount = 0

$ProfileExcludeListCount = (Compare-Object -ReferenceObject $Administrators -DifferenceObject $ProfileExcludeList -IncludeEqual | Where-Object {$_.SideIndicator -eq '=='}).InputObject.count
$ODFCExcludeListCount = (Compare-Object -ReferenceObject $Administrators -DifferenceObject $ODFCExcludeList -IncludeEqual | Where-Object {$_.SideIndicator -eq '=='}).InputObject.count

if(($ProfileExcludeListCount -and $ODFCExcludeListCount -eq $Administrators.Count) `
    -and ($ProfileIncludeList -and $ODFCIncludeList -eq "Everyone")){
    Write_Log -Message_Type "INFO" -Message "Local group permissions are set correctly"
    $EC += 0
}
else {
    Write_Log -Message_Type "ERROR" -Message "Failed to set the local group permissions" -ForegroundColor Red
    $EC += 1
}

$ExitCode = ($EC | Measure-Object -Sum).Sum
Write_Log -Message_Type "INFO" -Message "Exit code : $ExitCode"
Exit $ExitCode