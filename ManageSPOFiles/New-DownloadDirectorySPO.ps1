function New-DownloadDirectorySPO {
    <#
        .SYNOPSIS
        Can be used to download a full directory and files recursive from SharePoint Online locations.

        .DESCRIPTION
        Can be used to download a full directory and files recursive from SharePoint Online locations.

        .PARAMETER TenantName
        Mandatory to specify the tenant name.

        .PARAMETER SiteName
        Mandatory to specify the SharePoint site name.

        .PARAMETER DestinationPath
        Mandatory to specify the file location on the local machine to store the downloaded directory from SharePoint Online.

        .PARAMETER DriveName
        Mandatory to specify the DriveName like Documents.

        .PARAMETER SourcePath
        Mandatory to specify the directory on SharePoint Online.

        .NOTES
        AUTHOR   : Ivo Uenk
        CREATED  : 16/07/2025

        .EXAMPLE
        $TenantName = "TenantName"
        $SiteName = "Intune"
        $SourcePath = "ImportAutopilotDevice/Import"
        $DriveName = "Documents"
        $DestinationPath = "C:\Temp"
        New-DownloadDirectorySPO -TenantName $TenantName -SiteName $SiteName -DriveName $DriveName -SourcePath $SourcePath -DestinationPath $DesinationPath
    #>

	param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName,
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        [Parameter(Mandatory=$true)]
        [string]$DriveName,
        [Parameter(Mandatory=$true)]
        [string]$SourcePath
	)

    try {
        function Get-SPODriveItemsRecursively {
            param(
                [Parameter(Mandatory=$true)]
                [string]$FolderId,
                [Parameter(Mandatory=$true)]
                [string]$DriveId
            )

            try {
                # Get the child items of the specified folder
                Write-output "Getting child items of folder [$FolderId]"

                $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$($FolderId)/children"
                $DriveItems = Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET
            } 
            catch {
                Write-Error "Failed to get child items in folder [$FolderId]: $_"
            }

            foreach ($Item in $($DriveItems.value)){
                if ($($Item.folder)){
                    # Recursively get the children of the folder
                    Get-SPODriveItemsRecursively -FolderId $($Item.id) -DriveId $DriveId
                } 
                else {
                    $Item
                }
            }
        }

        $LibraryURL = "https://$($tenantName).sharepoint.com/sites/$($siteName)/$($DriveName)"
        
        # Retrieve necessary info
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($TenantName).sharepoint.com:/sites/$($SiteName)`?$select=id"
        $siteId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id).Split(",")[1]
        
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives"  
        $DriveId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $DriveName}).id     

        # Get folderId of package folder
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives/$DriveId/items/root:/$($sourcePath)"
        $FolderId = (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id

        # Recursively get all items in the specified Document Library path
        Write-output "Recursively retrieve all items in the SharePoint Document Library path [$LibraryURL/$SourcePath]."
        $PathItems = Get-SPODriveItemsRecursively -FolderId $FolderId -DriveId $DriveId

        # Filter folders out of the list of items to process
        $PathFiles = $PathItems | Where-Object {$_.file}

        Write-output "[$($PathFiles.Count)] files in the SharePoint Document Library path [$LibraryURL/$SourcePath]."

        # Download Files
        $CompletedFiles = 0

        foreach ($file in $PathFiles){
            # Parse SharePoint Document Library path
            $SPOFilePath = $file.parentReference.path.split('/root:/')[1]
            $localFilePath = $SPOFilePath.Remove(0, $SPOFilePath.IndexOf("/"))
            $localFilePath = $localFilePath.Replace("/", "\").Remove(0, 1)
            $localPath = $DestinationPath + "\" + $localFilePath

            # Create local path if not exist
            if (-not(Test-Path $localPath)){New-Item -ItemType Directory $localPath}

            Write-output "[$([math]::Round($file.Size / 1kb, 2)) KB] file [$($file.name)] will be downloaded to [$localPath]."
            try {
                # Download file from SharePoint
                Invoke-RestMethod -Uri $file.'@microsoft.graph.downloadUrl' -OutFile $($localPath + "\" + $($file.name)) -ProgressAction SilentlyContinue
                $CompletedFiles++
            } 
            catch {
                Write-Error "Failed to download file [$($SPOFilePath + "/" + $($file.name))] from SharePoint Online: $_"
            }
        }

        Write-output "Completed. Downloaded [$CompletedFiles] files from SharePoint Online."
    }
    catch {
        $Message = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($Null -eq $Message) { $Message = $($_.Exception.Message) }
        throw $Message
    }
}