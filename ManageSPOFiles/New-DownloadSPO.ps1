Function New-DownloadSPO {
    <#
        .SYNOPSIS
        Can be used to download files from SharePoint Online locations.

        .DESCRIPTION
        Can be used to download files from SharePoint Online locations.

        .PARAMETER SiteName
        Mandatory to specify the SharePoint site name.

        .PARAMETER DestinationPath
        Mandatory to specify the file location on the local machine to store the downloaded files from SharePoint Online.
        It will also retrieve info like FileName and CreatedBy and add it to $global:collItems.

        .PARAMETER FileExtension
        Mandatory to specify the files based on extension and download those (can be all kind of extensions no limitations).

        .PARAMETER DriveName
        Mandatory to specify the DriveName like Documents or Automation please check the SPO URL text after the site name.
        It is the first location metnioned after the SiteName. Examples below:
        https://<tenant>.sharepoint.com/sites/<SiteName>/Shared%20Documents = Documents
        https://<tenant>.sharepoint.com/sites/<SiteName>/Automation = Automation

        .PARAMETER SourcePath
        Optional to declare the SharePoint source of the file, by default the file will be downloaded from the root.

        .PARAMETER FileName
        Optional to download only the specified file from SharePoint.

        .PARAMETER MovePath
        Optional to move downloaded files from one SharePoint Online folder to another (only works in within same DriveName).
        The files will be renamed with a timestamp to avoid conflicts.

        .NOTES
        AUTHOR   : Ivo Uenk
        CREATED  : 23/01/2025

        .EXAMPLE
        $SiteName = "Intune"
        $SourcePath = "ImportAutopilotDevice/Import"
        $FileName = "DevicesImported.csv"
        $DriveName = "Documents"
        $DestinationPath = "C:\Temp"
        $FileExtension = "csv"
        $MovePath = "ImportAutopilotDevice/Sources"
        New-DownloadSPO -SiteName $SiteName -DestinationPath $DestinationPath -FileExtension $FileExtension -DriveName $DriveName
        New-DownloadSPO -SiteName $SiteName -DestinationPath $DestinationPath -FileExtension $FileExtension -DriveName $DriveName -SourcePath $SourcePath -FileName $FileName
        New-DownloadSPO -SiteName $SiteName -DestinationPath $DestinationPath -FileExtension $FileExtension -DriveName $DriveName -SourcePath $SourcePath -MovePath $MovePath
    #>

	param(
        [Parameter(Mandatory=$true)]$SiteName,
        [Parameter(Mandatory=$true)]$DestinationPath,
        [Parameter(Mandatory=$true)]$FileExtension,
        [Parameter(Mandatory=$true)]$DriveName,
        [Parameter(Mandatory=$false)]$FileName,
        [Parameter(Mandatory=$false)]$SourcePath,
        [Parameter(Mandatory=$false)]$MovePath
	)

    try {
        $global:collItems = @()

        $LibraryURL = "https://$($tenantName).sharepoint.com/sites/$($siteName)/$($DriveName)"
        
        # Retrieve necessary info
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($TenantName).sharepoint.com:/sites/$($SiteName)`?$select=id"
        $siteId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id).Split(",")[1]
        
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives"  
        $DriveId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $DriveName}).id

        if($MovePath){
            Write-output "MovePath specified [$MovePath]."
            $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives/$DriveId/items/root:/$($MovePath)"
            $MoveFolderId = (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id
        }        

        if(-not(!$SourcePath)){
            # Start process download file from SourcePath
            Write-output "SourcePath specified [$SourcePath]."

            $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives/$DriveId/items/root:/$($sourcePath)"
            $FolderId = (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id

            $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$FolderId/children"
    
            if(-not(!$FileName)){
                Write-output "FileName specified [$FileName] with extension [$FileExtension]."
                $FileName = $($FileName + "." + $FileExtension)
                $FolderItems = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $FileName})
            }
            else {
                Write-output "Get all files based on extension specified [$FileExtension]."
                $FolderItems = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -like "*.$FileExtension"})                     
            }                     

            if(-not(!$FolderItems)){
                foreach ($item in $FolderItems){
                    # Download files
                    $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$($item.Id)/content"  
                    Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET -OutFile $($DestinationPath + "\" + $($item.name)) -ContentType 'multipart/form-data'

                    $obj = new-object psobject -Property @{
                        FileName = $($item.name)
                        CreatedBy = $($item.createdby.user.email)
                    }
                    $global:collItems += $obj

                    Write-Output "File [$($LibraryURL + "/" + $SourcePath + "/" + $($item.name))] downloaded to [$DestinationPath]."

                    # Move file to adjacent folder (name must be unique otherwise Name already exists error)                   
                    if($MoveFolderId){
                        $ItemName = $(Get-Date -format "yyyymmdd-HHmm") + "_" + $($item.name)
                        $Body = @{
                            "parentReference" = @{
                                "id" = "$MoveFolderId"
                            }
                            "name" = "$ItemName"
                        } | ConvertTo-Json -depth 100

                        $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$($item.Id)"
                        (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method PATCH -Body $Body -ContentType 'application/json' | Out-Null)

                        Write-Output "Moved file [$($LibraryURL + "/" + $SourcePath + "/" + $($item.name))] to [$($LibraryURL + "/" + $($MovePath))]."
                    }
                }
            }
            else {
                Write-Output "No file(s) found in [$($LibraryURL + "/" + $($SourcePath))]."
            }
        }
        else {
            # Start process download file in root
            Write-Output "No SourcePath specified continue process root [$LibraryURL]."

            $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/root/children"
    
            if(-not(!$FileName)){
                Write-output "FileName specified [$FileName] with extension [$FileExtension]."
                $FileName = $($FileName + "." + $FileExtension)
                $FolderItems = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $FileName})
            }
            else {
                Write-output "Get all files based on extension specified [$FileExtension]."
                $FolderItems = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -like "*.$FileExtension"})                    
            }          

            if(-not(!$FolderItems)){
                foreach ($item in $FolderItems){
                    # Download files
                    $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$($item.Id)/content"  
                    Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET -OutFile $($DestinationPath + "\" + $($item.name)) -ContentType 'multipart/form-data'

                    $obj = new-object psobject -Property @{
                        FileName = $($item.name)
                        CreatedBy = $($item.createdby.user.email)
                    }
                    $global:collItems += $obj

                    Write-Output "File [$($LibraryURL + "/" + $($item.name))] downloaded to [$DestinationPath]."
    
                    # Move file to adjacent folder (name must be unique otherwise Name already exists error)
                    if($MoveFolderId){
                        $ItemName = $(Get-Date -format "yyyymmdd-HHmm") + "_" + $($item.name)
                        $Body = @{
                            "parentReference" = @{
                                "id" = "$MoveFolderId"
                            }
                            "name" = "$ItemName"
                        } | ConvertTo-Json -depth 100

                        $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$($item.Id)"
                        (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method PATCH -Body $Body -ContentType 'application/json' | Out-Null)

                        Write-Output "Moved file [$($LibraryURL + "/" + $($item.name))] to [$($LibraryURL + "/" + $($MovePath))]."                            
                    }
                }
            }
            else {
                Write-Output "No file(s) found in [$LibraryURL]."
            }
        }
    }
    catch {
        $Message = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($Null -eq $Message) { $Message = $($_.Exception.Message) }
        throw $Message
    }
}