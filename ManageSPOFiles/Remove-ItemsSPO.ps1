function Remove-ItemsSPO {
    <#
        .SYNOPSIS
        Can be used to remove directories and files from specified SharePoint Online location.

        .DESCRIPTION
        Can be used to remove directories and files from specified SharePoint Online location.

        .PARAMETER TenantName
        Mandatory to specify the tenant name.

        .PARAMETER SiteName
        Mandatory to specify the SharePoint site name.

        .PARAMETER DestinationPath
        Mandatory to specify the location in SPO you want to remove directories and files.

        .PARAMETER DriveName
        Mandatory to specify the DriveName like Documents or Automation please check the SPO URL text after the site name.
        It is the first location metnioned after the SiteName. Examples below:
        https://<tenant>.sharepoint.com/sites/<SiteName>/Shared%20Documents = Documents
        https://<tenant>.sharepoint.com/sites/<SiteName>/Automation = Automation

        .NOTES
        AUTHOR   : Ivo Uenk
        CREATED  : 14/07/2025

        .EXAMPLE
        $SiteName = "Intune"
        $DriveName = "Documents"
        $DestinationPath = "Reports"
        Remove-ItemsSPO -TenantName $TenantName -SiteName $SiteName -DriveName $DriveName -DestinationPath $DestinationPath
    #>

    param(
        [Parameter(Mandatory=$true)]$TenantName,
        [Parameter(Mandatory=$true)]$SiteName,
        [Parameter(Mandatory=$true)]$DriveName,
        [Parameter(Mandatory=$true)]$DestinationPath
    )

    try {
        $LibraryURL = "https://$($tenantName).sharepoint.com/sites/$($siteName)/$($DriveName)"

        # Retrieve necessary info
        $Uri = "https://graph.microsoft.com/v1.0/sites/$($TenantName).sharepoint.com:/sites/$($SiteName)`?$select=id"
        $siteId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id).Split(",")[1]

        $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives"  
        $DriveId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $DriveName}).id

        # Remove directory and all directories and files in it
        Write-output "DestinationPath specified [$DestinationPath]."

        $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives/$($DriveId)/items/root:/$($DestinationPath)"
        $FolderId = (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).Id

        $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$FolderId/children"
        $FolderItems = Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET

        foreach ($item in $FolderItems){
            $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/$($item.Id)"
            Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method DELETE
            Write-output "Removed item [$($LibraryURL + "/" + $DestinationPath + "/" + $($item.name))]."
        }
    }
    catch {
        $Message = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($Null -eq $Message) { $Message = $($_.Exception.Message) }
        throw $Message
    }
}