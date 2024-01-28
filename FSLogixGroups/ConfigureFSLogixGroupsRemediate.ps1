#=============================================================================================================================
#
# Script Name:     ConfigureFSLogixGroupsRemediate.ps1
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
$ScriptName = 'ConfigureFSLogixGroups_Remediate'
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

Write_Log -Message_Type "INFO" -Message "############################ $ScriptName REMEDIATE ############################"

#Remediate
# Get all members from the Administrators group 
$Administrators = @()
foreach($group in Get-LocalGroup -Name "Administrators"){
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$group"
    $group_members = @($group.Invoke('Members') | % {([adsi]$_).path})

    foreach($group_member in $group_members){
        $Administrators += ($group_member.split('/'))[-1]
    }
}

try{
    # Get all administrator users and check for Azure AD account add those to the FSLogix exclude list
    foreach($Administrator in $Administrators){

        try{
            Add-LocalGroupMember -Group "FSLogix Profile Exclude List" -Member $Administrator -ErrorAction Stop
        }catch [Microsoft.PowerShell.Commands.MemberExistsException]{Write_Log -Message_Type "INFO" -Message "$Administrator already in FSLogix Profile Exclude List"}

        try{
            Add-LocalGroupMember -Group "FSLogix ODFC Exclude List" -Member $Administrator -ErrorAction Stop
        }catch [Microsoft.PowerShell.Commands.MemberExistsException]{Write_Log -Message_Type "INFO" -Message "$Administrator already in FSLogix ODFC Exclude List"}
    }

    # Add Everyone to the FSLogix include list
    try{
        Add-LocalGroupMember -Group "FSLogix Profile Include List" -Member "Everyone" -ErrorAction Stop
    }catch [Microsoft.PowerShell.Commands.MemberExistsException]{Write_Log -Message_Type "INFO" -Message "Everyone already in FSLogix Profile Include List"}

    try{
        Add-LocalGroupMember -Group "FSLogix ODFC Include List" -Member "Everyone" -ErrorAction Stop
    }catch [Microsoft.PowerShell.Commands.MemberExistsException]{Write_Log -Message_Type "INFO" -Message "Everyone already in FSLogix ODFC Include List"}

    Write_Log -Message_Type "INFO" -Message "Local group permissions are set correctly"
    $EC += 0
}
catch {
    Write_Log -Message_Type "ERROR" -Message "Failed to set the local group permissions" -ForegroundColor Red
    $EC += 1
}

$ExitCode = ($EC | Measure-Object -Sum).Sum
Write_Log -Message_Type "INFO" -Message "Exit code : $ExitCode"
Exit $ExitCode