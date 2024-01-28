# Change app to detect
$AppToDetect = "7zip.7zip"

# Functions

Function Get-WingetCmd {

    $WingetCmd = $null

    # Get Admin Context Winget Location
    $WingetInfo = (Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe").VersionInfo | Sort-Object -Property FileVersionRaw
    # If multiple versions, pick most recent one
    $WingetCmd = $WingetInfo[-1].FileName

    return $WingetCmd
}

# Main logic

# Get WinGet Location Function
$winget = Get-WingetCmd

# Set json export file
$JsonFile = "$env:TEMP\InstalledApps.json"

# Get installed apps and version in json file
& $Winget export -o $JsonFile --accept-source-agreements | Out-Null

# Get json content
$Json = Get-Content $JsonFile -Raw | ConvertFrom-Json

# Get apps and version in hashtable
$Packages = $Json.Sources.Packages

# Remove json file
Remove-Item $JsonFile -Force

# Search for specific app and version
$Apps = $Packages | Where-Object { $_.PackageIdentifier -eq $AppToDetect }

if ($Apps){
    return "Installed!"
}