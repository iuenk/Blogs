Function New-UploadSPO {
    <#
        .SYNOPSIS
        Can be used to upload files to SharePoint Online locations.

        .DESCRIPTION
        Can be used to upload files to SharePoint Online locations.

        .PARAMETER TenantName
        Mandatory to specify the tenant name.

        .PARAMETER SiteName
        Mandatory to specify the SharePoint site name.

        .PARAMETER SourcePath
        Mandatory to specify one or more files located on the local machine. To specify multiple files use a comma separated string.

        .PARAMETER DestinationPath
        Optional to declare the SharePoint destination of the file, by default the file will be uploaded in the root.

        .NOTES
        AUTHOR   : Ivo Uenk
        CREATED  : 11/12/2024

        .EXAMPLE
        $TenantName = "ucorponline"
        $SiteName = "Intune"
        $SourcePath = "C:\Temp\DevicesImported1.csv,C:\Temp\DevicesImported2.csv"
        $DestinationPath = "ImportAutopilotDevice/Import"
        New-UploadSPO -TenantName $TenantName -SiteName $SiteName -SourcePath $SourcePath -DestinationPath $DestinationPath
    #>

	param(
        [Parameter(Mandatory=$true)]$TenantName,
		[Parameter(Mandatory=$true)]$SiteName,
        [Parameter(Mandatory=$true)]$SourcePath,
		[Parameter(Mandatory=$false)]$DestinationPath
	)

    try {
        $Sources = $SourcePath.Split(",")

        foreach ($SourcePath in $Sources){
            if (-not(Test-Path $SourcePath)){
                throw "File [$SourcePath] not found."
            }

            $FileName = $SourcePath.Split("\")[-1]
            $LibraryURL = "https://$($tenantName).sharepoint.com/sites/$($siteName)/Shared%20Documents"

            # Retrieve necessary info
            $Uri = "https://graph.microsoft.com/v1.0/sites/$($TenantName).sharepoint.com:/sites/$($SiteName)`?$select=id"
            $siteId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id).Split(",")[1]

            $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives"  
            $DriveId = (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value.id

            if(-not(!$DestinationPath)){
                # Start process upload file to DestinationPath
                Write-output "DestinationPath specified [$DestinationPath]."

                # Start upload file 
                $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/root:/$($DestinationPath)/$($FileName):/content"
                (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method PUT -InFile $SourcePath -ContentType 'multipart/form-data' | Out-Null)

                Write-output "File [$SourcePath] uploaded to destination [$($LibraryURL + "/" + $DestinationPath)]."
            }
            else {
                # No specific DestinationPath specified file need to be uploaded in root
                Write-Output "No DestinationPath specified continue process root [$LibraryURL]."

                $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/root:/$($FileName):/content"

                # Start upload file 
                (Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method PUT -InFile $SourcePath -ContentType 'multipart/form-data' | Out-Null)

                Write-output "File [$SourcePath] uploaded to destination [$($LibraryURL)]."
            }
        }
    }
    catch {
        $Message = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($Null -eq $Message) { $Message = $($_.Exception.Message) }
        throw $Message
    }
}