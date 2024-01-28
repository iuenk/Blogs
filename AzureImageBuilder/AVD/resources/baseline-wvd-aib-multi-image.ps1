<#
.Synopsis
    Customization script for Azure Image Builder
.DESCRIPTION
    Customization script for Azure Image Builder - Baseline Windows 10 enterprise multi-session
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

# HideSCAMeetNow
New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1 -force
Write-Log -LogOutput ("Added HideSCAMeetNow registry key") -Path $LogFile

# Add MSIX app attach certificate
Invoke-WebRequest -Uri 'https://github.com/iuenk/AVD/raw/main/Resources/Ucorp-MSIX-20092021.pfx' -OutFile "$path\Ucorp-MSIX-20092021.pfx"
Import-PfxCertificate -FilePath "$path\Ucorp-MSIX-20092021.pfx" -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -Password (ConvertTo-SecureString -String 'Welkom01!' -AsPlainText -Force) -Exportable
Write-Log -LogOutput ("Configured MSIX app attach certificate") -Path $LogFile

# Configuring FSLogix
$fileServer="ucorpavdprdfslogix.file.core.windows.net"
$profileShare="\\$($fileServer)\fslogixprofiles" 

New-Item -Path "HKLM:\SOFTWARE" -Name "FSLogix" -ErrorAction Ignore
New-Item -Path "HKLM:\SOFTWARE\FSLogix" -Name "Profiles" -ErrorAction Ignore
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "Enabled" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "VHDLocations" -Value $profileShare -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "RedirXMLSourceFolder" -Value $profileShare -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "FlipFlopProfileDirectoryName" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "IsDynamic" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "SetTempToLocalPath" -Value 3 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "ProfileType" -Value 0 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "SizeInMBs" -Value 40000 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "VolumeType" -Value "VHDX" -force

$fileServer="ucorpavdprdfslogix.file.core.windows.net"
$profileShare="\\$($fileServer)\fslogixoffice" 

New-Item -Path "HKLM:\SOFTWARE\Policies" -Name "FSLogix" -ErrorAction Ignore
New-Item -Path "HKLM:\SOFTWARE\Policies\FSLogix" -Name "ODFC" -ErrorAction Ignore
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "Enabled" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "VHDLocations" -Value $profileShare -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "IncludeOfficeActivation" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "IncludeOutlook" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC"-Name "IncludeTeams" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "FlipFlopProfileDirectoryName" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "SizeInMBs" -Value 55000 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "MirrorLocalOSTToVHD" -Value 2 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "IsDynamic" -Value 1 -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -Name "VolumeType" -Value "VHDX" -force
Write-Log -LogOutput ("Configured FSLogix") -Path $LogFile

# Add MSIX app attach certificate (password is not sensitive in this case certificate only used by MSIX app attach)
Write-Log -LogOutput ("Set MSIX app attach certificate") -Path $LogFile
Invoke-WebRequest -Uri 'https://github.com/iuenk/AVD/blob/main/resources/msix-20092021.pfx?raw=true' -OutFile "$path\msix-20092021.pfx"
Import-PfxCertificate -FilePath "$path\msix-20092021.pfx" -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -Password (ConvertTo-SecureString -String 'Welkom01!' -AsPlainText -Force) -Exportable

# Install Microsoft 365 Apps with customization
Invoke-WebRequest -Uri 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=languagepack&language=nl-nl&platform=x64&source=O16LAP&version=O16GA' -OutFile 'C:\AIB\OfficeSetup.exe'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/iuenk/AVD/main/resources/office-configuration.xml' -OutFile 'C:\AIB\office-configuration.xml'

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