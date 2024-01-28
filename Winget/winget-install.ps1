#=============================================================================================================================
#
# Script Name:     winget-install.ps1
# Description:     Will configure the AppInstaller used for Winget and install all apps specified.
#   
# Notes      :     Forward Winget App ID to install. For multiple apps, separate with ",". Case sensitive.
#                  %SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command .\winget-install.ps1 -AppIDs 7zip.7zip -v "7zip.7zip -v 22.00", "Notepad++.Notepad++"
#
#                  To uninstall app. Works with AppIDs.
#                  %SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command .\winget-install.ps1 -AppIDs 7zip.7zip -Uninstall
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $True, ParameterSetName = "AppIDs")] [String[]] $AppIDs,
    [Parameter(Mandatory = $False)] [Switch] $Uninstall
)

# Functions

if(!$Uninstall){
    $LogFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Winget_Install_$(((Get-Date).ToString("dd-MM-yyyy-HHmm"))).log"
}
else {
    $LogFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Winget_Uninstall_$(((Get-Date).ToString("dd-MM-yyyy-HHmm"))).log"
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

# Get WinGet Location Function
function Get-WingetCmd {

    $WingetCmd = $null # Get system context Winget Location
    $WingetInfo = (Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe").VersionInfo | Sort-Object -Property FileVersionRaw # If multiple versions, pick most recent one
    $WingetCmd = $WingetInfo[-1].FileName #If multiple versions, pick most recent one

    return $WingetCmd
}

function Install-Prerequisites {

    Write-Log -LogOutput ("Checking prerequisites...") -Path $LogFile

    # Check if Visual C++ 2019 or 2022 installed
    $Visual2019 = "Microsoft Visual C++ 2015-2019 Redistributable*"
    $Visual2022 = "Microsoft Visual C++ 2015-2022 Redistributable*"
    $path = Get-Item HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | `
    Where-Object { $_.GetValue("DisplayName") -like $Visual2019 -or $_.GetValue("DisplayName") -like $Visual2022 }

    # If not installed, download and install
    if (!($path)){
        Write-Log -LogOutput ("Microsoft Visual C++ 2015-2022 is not installed.") -Path $LogFile

        try {
            $OSArch = "x64" # Architecture OS
            $SourceURL = "https://aka.ms/vs/17/release/VC_redist.$OSArch.exe"
            $Installer = "$env:TEMP\VC_redist.$OSArch.exe"
            Invoke-WebRequest $SourceURL -UseBasicParsing -OutFile $Installer
            Start-Process -FilePath $Installer -Args "/passive /norestart" -Wait
            Start-Sleep 3
            Remove-Item $Installer -ErrorAction Ignore
            Write-Log -LogOutput ("MS Visual C++ 2015-2022 installed successfully.") -Path $LogFile
        }
        catch {
            Write-Log -LogOutput ("MS Visual C++ 2015-2022 installation failed.") -Path $LogFile
            Write-Error "MS Visual C++ 2015-2022 installation failed."
        }
    }

    # Check if Microsoft.VCLibs.140.00.UWPDesktop is installed
    if (!(Get-AppxPackage -Name 'Microsoft.VCLibs.140.00.UWPDesktop' -AllUsers)){
        Write-Log -LogOutput ("Microsoft.VCLibs.140.00.UWPDesktop is not installed.") -Path $LogFile
        $VCLibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $VCLibsFile = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Invoke-RestMethod -Uri $VCLibsUrl -OutFile $VCLibsFile
        
        try {
            Add-AppxProvisionedPackage -Online -PackagePath $VCLibsFile -SkipLicense | Out-Null
            Write-Log -LogOutput ("Microsoft.VCLibs.140.00.UWPDesktop installed successfully.") -Path $LogFile
            Remove-Item -Path $VCLibsFile -Force
        }
        catch {
            Write-Log -LogOutput ("Failed to intall Microsoft.VCLibs.140.00.UWPDesktop...") -Path $LogFile
            Remove-Item -Path $VCLibsFile -Force
            Write-Error "MS Visual C++ 2015-2022 installation failed."
        }
    }

    $WingetURL = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' #Check available WinGet version

    try {
        $WinGetAvailableVersion = ((Invoke-WebRequest $WingetURL -UseBasicParsing | ConvertFrom-Json)[0].tag_name).Replace("v", "")
        Write-Log -LogOutput ("Latest available Winget version found [$WinGetAvailableVersion].") -Path $LogFile
    }
    catch {
        Write-Log -LogOutput ("No Winget version could be found.") -Path $LogFile
        Write-Error "No Winget version could be found."
    }

    try {
        $WingetInstalledVersionCmd = & $Winget -v
        $WinGetInstalledVersion = (($WingetInstalledVersionCmd).Replace("-preview", "")).Replace("v", "")
        Write-ToLog "Installed Winget version: $WingetInstalledVersionCmd"
    }
    catch {
        Write-Log -LogOutput ("WinGet is not installed.") -Path $LogFile
    }

    # Check if the available WinGet version is newer than installed
    if ($WinGetAvailableVersion -gt $WinGetInstalledVersion) {

        $WingetURL = "https://github.com/microsoft/winget-cli/releases/download/v$WinGetAvailableVersion/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $WingetInstaller = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Invoke-RestMethod -Uri $WingetURL -OutFile $WingetInstaller
        try {
            Add-AppxProvisionedPackage -Online -PackagePath $WingetInstaller -SkipLicense | Out-Null
            Write-Log -LogOutput ("Winget version [$WinGetAvailableVersion] installed.") -Path $LogFile
            Remove-Item -Path $WingetInstaller -Force
        }
        catch {
            Write-Log -LogOutput ("Failed to install Winget version [$WinGetAvailableVersion].") -Path $LogFile
            Write-Error "Failed to install Winget version [$WinGetAvailableVersion]."
            Remove-Item -Path $WingetInstaller -Force
        }
    }
    Write-Log -LogOutput ("Checking prerequisites ended.") -Path $LogFile
}

# Function to configure prefered scope option as Machine
function Add-ScopeMachine {
    # Get Settings path for system
    $SettingsPath = "$Env:windir\System32\config\systemprofile\AppData\Local\Microsoft\WinGet\Settings\defaultState\settings.json"
    $ConfigFile = @{}

    # Check if setting file exist, if not create it
    if (Test-Path $SettingsPath){
        $ConfigFile = Get-Content -Path $SettingsPath | Where-Object { $_ -notmatch '//' } | ConvertFrom-Json
    }
    else {
        New-Item -Path $SettingsPath -Force | Out-Null
    }

    if ($ConfigFile.installBehavior.preferences){
        Add-Member -InputObject $ConfigFile.installBehavior.preferences -MemberType NoteProperty -Name 'scope' -Value 'Machine' -Force
    }
    else {
        $Scope = New-Object PSObject -Property $(@{scope = 'Machine'})
        $Preference = New-Object PSObject -Property $(@{preferences = $Scope})
        Add-Member -InputObject $ConfigFile -MemberType NoteProperty -Name 'installBehavior' -Value $Preference -Force
    }

    $ConfigFile | ConvertTo-Json | Out-File $SettingsPath -Encoding utf8 -Force
}

# Check if App exists in Winget Repository
function Confirm-Exist ($AppID){

    $WingetApp = & $winget show --Id $AppID -e --accept-source-agreements -s winget | Out-String #Check is app exists in the winget repository

    # Return if AppID exists
    if ($WingetApp -match [regex]::Escape($AppID)){
        Write-Log -LogOutput ("App [$AppID] exists on Winget Repository.") -Path $LogFile
        return $true
    }
    else {
        Write-Log -LogOutput ("App [$AppID] does not exist on Winget Repository! Check spelling.") -Path $LogFile
        return $false
    }
}

# Check if app is installed
function Confirm-Install ($AppID) {
    #Get "Winget List AppID"
    $InstalledApp = & $winget list --Id $AppID -e --accept-source-agreements -s winget | Out-String

    #Return if AppID exists in the list
    if ($InstalledApp -match [regex]::Escape($AppID)) {
        return $true
    }
    else {
        return $false
    }
}

# Install function
function Install-App ($AppID, $AppArgs){
    $IsInstalled = Confirm-Install $AppID

    if (!($IsInstalled)){
        # Install App
        Write-Log -LogOutput ("Installing App [$AppID]...") -Path $LogFile
        $WingetArgs = "install --id $AppID -e --accept-package-agreements --accept-source-agreements -s winget -h $AppArgs" -split " "
        & "$Winget" $WingetArgs | Where-Object { $_ -notlike "   *" } | Tee-Object -file $LogFile -Append

        # Check if app is installed
        $IsInstalled = Confirm-Install $AppID
        if ($IsInstalled){
            Write-Log -LogOutput ("App [$appID] successfully installed.") -Path $LogFile
        }
        else {
            Write-Log -LogOutput ("App [$appID] installation failed!") -Path $LogFile
            Write-Error "App [$appID] installation failed!"
        }
    }
    else {
        Write-Log -LogOutput ("App [$appID] is already installed.") -Path $LogFile
    }
}

# Uninstall function
function Uninstall-App ($AppID, $AppArgs){
    $IsInstalled = Confirm-Install $AppID
    
    if ($IsInstalled){
        # Uninstall App
        Write-Log -LogOutput ("Uninstalling App [$AppID]...") -Path $LogFile
        $WingetArgs = "uninstall --id $AppID -e --accept-source-agreements -h" -split " "
        & "$Winget" $WingetArgs | Where-Object { $_ -notlike "   *" } | Tee-Object -file $LogFile -Append

        # Check if app is uninstalled
        $IsInstalled = Confirm-Install $AppID # Check if app is uninstalled
        if (!($IsInstalled)) {
            Write-Log -LogOutput ("App $AppID successfully removed.") -Path $LogFile
        }
        else {
            Write-Log -LogOutput ("App [$appID] removal failed!") -Path $LogFile
            Write-Error "App [$appID] removal failed!"
        }
    }
    else {
        Write-Log -LogOutput ("App [$appID] is already removed.") -Path $LogFile
        Write-Error "App [$appID] is already removed."
    }
}

# Main logic

# If running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64"){
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        Start-Process "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $($MyInvocation.line)"
        Exit $lastexitcode
    }
}

# Config console output encoding
$null = cmd /c '' #Tip for ISE
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Script:ProgressPreference = 'SilentlyContinue'

# Check if current process is elevated (System or admin user)
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$Script:IsElevated = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Get Winget command
if ($IsElevated -eq $True){

    $Script:Winget = Get-WingetCmd

    #Check/install prerequisites
    Install-Prerequisites

    #Reload Winget command
    $Script:Winget = Get-WingetCmd

    #Run Scope Machine funtion
    Add-ScopeMachine
}
else {
    Write-Log -LogOutput ("Running without admin rights.") -Path $LogFile
    Write-Error "Running without admin rights."
}

if ($Winget){
    # Run install or uninstall for all apps
    foreach ($App_Full in $AppIDs){
        # Split AppID and Custom arguments
        $AppID, $AppArgs = ($App_Full.Trim().Split(" ", 2))

        # Log current App
        Write-Log -LogOutput ("Start App [$AppID] processing...") -Path $LogFile

        # Install or Uninstall command
        if ($Uninstall){
            Uninstall-App $AppID $AppArgs
        }
        else {
            # Check if app exists on Winget Repo
            $Exists = Confirm-Exist $AppID
            if ($Exists) {
                #Install
                Install-App $AppID $AppArgs
            }
        }

        Write-Log -LogOutput ("App [$AppID] processing finished!") -Path $LogFile
        Start-Sleep 1
    }
}