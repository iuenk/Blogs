function New-UploadDirectorySPO {
    <#
        .SYNOPSIS
        Can be used to download a full directory and files recursive from SharePoint Online locations.
        Beware of the message "This operation is currently limited to supporting files less than 2 gigabytes in size sharepoint".
        Files larger than 2GB will not be uploaded.

        .DESCRIPTION
        Can be used to download a full directory and files recursive from SharePoint Online locations.

        .PARAMETER TenantName
        Mandatory to specify the tenant name.

        .PARAMETER SiteName
        Mandatory to specify the SharePoint site name.

        .PARAMETER DestinationPath
        Mandatory to specify the directory on SharePoint Online.

        .PARAMETER DriveName
        Mandatory to specify the DriveName like Documents.

        .PARAMETER SourcePath
        Mandatory to specify the file location on the local machine to store the downloaded directory from SharePoint Online.

        .NOTES
        AUTHOR   : Ivo Uenk
        CREATED  : 16/07/2025

        .EXAMPLE
        $TenantName = "TenantName"
        $SiteName = "Intune"
        $SourcePath = "C:\Temp"
        $DriveName = "Documents"
        $DestinationPath = "ImportAutopilotDevice/Import"
        New-UploadDirectorySPO -TenantName $TenantName -SiteName $SiteName -DriveName $DriveName -SourcePath $SourcePath -DestinationPath $DesinationPath
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName,
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$DriveName,
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    try {
        $AppName = $SourcePath.Split("\")[-1]
        $BaseDirectory = $SourcePath.Substring(0, $SourcePath.lastIndexOf('\'))

        $LibraryURL = "https://$($tenantName).sharepoint.com/sites/$($siteName)/$($DriveName)"

        # Retrieve necessary info
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($TenantName).sharepoint.com:/sites/$($SiteName)`?$select=id"
        $siteId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id).Split(",")[1]

        $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives"  
        $DriveId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $DriveName}).id

        # Create all the folders on the SharePoint site first
        # I've set microsoft.graph.conflictBehavior below to replace because I want to overwrite if exists
        $directories = get-childItem -path $SourcePath -recurse -directory

        foreach ($directory in $directories){
            # Start with directory
            $path = $($directory.parent.FullName).Replace($BaseDirectory, '')

            $createFolderURL = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/root:/$($DestinationPath){0}:/children"  -f $path
            $Uri = $createFolderURL.replace('\','/')

            $uploadFolderRequestBody = @{
                name = "$($directory.Name)"
                folder = @{}
                "@microsoft.graph.conflictBehavior" = "replace"
            } | ConvertTo-Json
    
            Invoke-Restmethod -Uri $Uri -Headers $($global:authHeader) -method POST -body $uploadFolderRequestBody -ContentType "application/json" | Out-Null
        }
        Write-output "Directories created in destination [$($LibraryURL + "/" + $($DestinationPath) + "/" + $($AppName))]."

        # Upload the files
        $sharefiles = get-childItem  $SourcePath -recurse | Where-Object{!$_.PSIsContainer}

        foreach ($sharefile in $sharefiles){
            $Filepath = $($sharefile.FullName)
            $Filename = $($sharefile.Name)

            $uploadSessionURL = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/$($DestinationPath){0}/$($Filename):/createUploadSession" -f $($sharefile.directory.FullName)
            $Uri = $uploadSessionURL.replace($BaseDirectory, '').Replace('\','/')
            $uploadURL = (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method POST).uploadUrl

            $fileInBytes = [System.IO.File]::ReadAllBytes($Filepath)
            $fileLength = $fileInBytes.Length

            $partSizeBytes = 320 * 1024 * 128
            $index = 0
            $start = 0
            $end = 0

            $maxloops = [Math]::Round([Math]::Ceiling($fileLength / $partSizeBytes))

            while ($fileLength -gt ($end + 1)){
                $start = $index * $partSizeBytes
                if (($start + $partSizeBytes - 1 ) -lt $fileLength){
                    $end = ($start + $partSizeBytes - 1)
                }
                else {
                    $end = ($start + ($fileLength - ($index * $partSizeBytes)) - 1)
                }
                [byte[]]$body = $fileInBytes[$start..$end]
                $headers = @{
                    'Authorization' = $global:token.CreateAuthorizationHeader()    
                    'Content-Range' = "bytes $start-$end/$fileLength"
                }

                Write-output "Bytes [$start-$end/$fileLength] | Index: [$index] and ChunkSize: [$partSizeBytes]."
                Invoke-WebRequest -Uri $uploadURL -Headers $headers -Method PUT -Body $body -UseBasicParsing | Out-Null
                $index++
                Write-output "Percentage Complete: $([Math]::Ceiling($index/$maxloops*100)) %"
            }
            Write-output "File [$Filepath] uploaded to destination [$($LibraryURL + "/" + $($DestinationPath) + "/" + $($AppName))]."
        }
    }
    catch {
        $Message = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($Null -eq $Message) { $Message = $($_.Exception.Message) }
        throw $Message
    }
}