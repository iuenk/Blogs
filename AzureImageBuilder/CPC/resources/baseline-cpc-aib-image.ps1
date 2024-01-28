<#
.Synopsis
    Customization script for Azure Image Builder
.DESCRIPTION
    Customization script for Azure Image Builder - Baseline Windows 11 Enterprise used for Windows 365 Cloud PC
.NOTES
    Author: Ivo Uenk
    Version: 1.0
#>

$path = "C:\AIB"
mkdir $path

$LogFile = $path + "\" + "Baseline-Configuration-" + (Get-Date -UFormat "%d-%m-%Y") + ".log"

Function Write-Log
{
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

# Disable Store auto update
Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable
Write-Log -LogOutput ("Disable Store auto update") -Path $LogFile

# region Time Zone Redirection
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fEnableTimeZoneRedirection" -Value 1 -force
Write-Log -LogOutput ("Added time zone redirection registry key") -Path $LogFile

# Set restart button on Windows 365 Cloud PC so users are able to reboot directly from within the desktop environment
$RegCheck = 'RestartButtonCPC'
$version = 1
$RegRoot= "HKLM"
if (Test-Path "$RegRoot`:\Software\Ucorp") {
    try{
        $regexist = Get-ItemProperty "$RegRoot`:\Software\Ucorp" -Name $RegCheck -ErrorAction Stop
    }catch{
        $regexist = $false
    }
} 
else {
    New-Item "$RegRoot`:\Software\Ucorp"
}    
if ((!($regexist)) -or ($regexist.$RegCheck -lt $Version)) {
    try {
        $user = "Users"
        $tmp = [System.IO.Path]::GetTempFileName()
        secedit.exe /export /cfg $tmp
        $settings = Get-Content -Path $tmp
        $account = New-Object System.Security.Principal.NTAccount($user)
        $sid =   $account.Translate([System.Security.Principal.SecurityIdentifier])
        for($i=0;$i -lt $settings.Count;$i++){
            if($settings[$i] -match "SeShutdownPrivilege")
            {
                $settings[$i] += ",*$($sid.Value)"
            }
        }
        $settings | Out-File $tmp
        secedit.exe /configure /db secedit.sdb /cfg $tmp  /areas User_RIGHTS
        Remove-Item -Path $tmp
    }
    catch {
        write-error 'Unable to add the users group to Shut down the system policy'
        break 
    }

    if(!($regexist)){
        New-ItemProperty "$RegRoot`:\Software\Ucorp" -Name $RegCheck -Value $Version -PropertyType string
    }else{
        Set-ItemProperty "$RegRoot`:\Software\Ucorp" -Name $RegCheck -Value $version
    }
}
Write-Log -LogOutput ("Restart button is set") -Path $LogFile

# Install Dutch language and set als default
Install-Language nl-NL
Set-SystemPreferredUILanguage nl-NL
Write-Log -LogOutput ("Default language is installed and set") -Path $LogFile

# Install Microsoft 365 Apps with customization
Invoke-WebRequest -Uri 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=languagepack&language=nl-nl&platform=x64&source=O16LAP&version=O16GA' -OutFile 'C:\AIB\OfficeSetup.exe'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/iuenk/MEM/main/resources/office-configuration.xml' -OutFile 'C:\AIB\office-configuration.xml'

Invoke-Expression -command 'C:\AIB\OfficeSetup.exe /configure C:\AIB\office-configuration.xml'
Start-Sleep -Seconds 600
Write-Log -LogOutput ("Installed Microsoft 365 Apps with customization") -Path $LogFile

# Remove data but keep logging
$var="log"
$array= @(get-childitem $path -exclude *.$var -name)
for ($i=0; $i -lt $array.length; $i++){
    $removepath=join-path -path $path -childpath $array[$i]
    remove-item $removepath -Recurse
}