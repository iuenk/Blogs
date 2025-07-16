function New-UploadLargeSPO {
    <#
        .SYNOPSIS
        Can be used to upload large files in chunks to SharePoint Online locations.
        Beware of the message "This operation is currently limited to supporting files less than 2 gigabytes in size sharepoint".
        Files larger than 2GB will not be uploaded.

        .DESCRIPTION
        Can be used to upload large files in chunks to SharePoint Online locations.

        .PARAMETER TenantName
        Mandatory to specify the tenant name.

        .PARAMETER SiteName
        Mandatory to specify the SharePoint site name.

        .PARAMETER SourcePath
        Mandatory to specify one or more files located on the local machine. To specify multiple files use a comma separated string.

        .PARAMETER DriveName
        Mandatory to specify the DriveName like Documents.

        .PARAMETER DestinationPath
        Optional to declare the SharePoint destination of the file, by default the file will be uploaded in the root.

        .NOTES
        AUTHOR   : Ivo Uenk
        CREATED  : 16/07/2025

        .EXAMPLE
        $TenantName = "TenantName"
        $SiteName = "Intune"
        $SourcePath = "C:\Temp\DevicesImported1.csv,C:\Temp\DevicesImported2.csv"
        $DriveName = "Documents"
        $DestinationPath = "ImportAutopilotDevice/Import"
        New-UploadSPO -TenantName $TenantName -SiteName $SiteName -SourcePath $SourcePath -DriveName $DriveName
        New-UploadSPO -TenantName $TenantName -SiteName $SiteName -SourcePath $SourcePath -DriveName $DriveName -DestinationPath $DestinationPath
    #>

	param(
        [Parameter(Mandatory=$true)]$TenantName,
		[Parameter(Mandatory=$true)]$SiteName,
        [Parameter(Mandatory=$true)]$SourcePath,
        [Parameter(Mandatory=$true)]$DriveName,
		[Parameter(Mandatory=$false)]$DestinationPath
	)

    try {
        $Sources = $SourcePath.Split(",")

        foreach ($SourcePath in $Sources){
            if (-not(Test-Path $SourcePath)){
                throw "File [$SourcePath] not found."
            }

            $FileName = $SourcePath.Split("\")[-1]
            $LibraryURL = "https://$($tenantName).sharepoint.com/sites/$($siteName)/$($DriveName)"

            # Retrieve necessary info
            $Uri = "https://graph.microsoft.com/v1.0/sites/$($TenantName).sharepoint.com:/sites/$($SiteName)`?$select=id"
            $siteId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).id).Split(",")[1]

            $Uri = "https://graph.microsoft.com/v1.0/sites/$($siteId)/drives"  
            $DriveId = ((Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method GET).value | Where-Object {$_.name -eq $DriveName}).id

            if(-not(!$DestinationPath)){
                # Start process upload file to DestinationPath
                Write-output "DestinationPath specified [$DestinationPath]."

                Write-output "Creating an upload session..."
                $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/root:/$($DestinationPath)/$($FileName):/createUploadSession"
                $uploadSessionUri = Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method POST

                Write-output "Getting local file [$sourcePath]."
                $fileInBytes = [System.IO.File]::ReadAllBytes($sourcePath)
                $fileLength = $fileInBytes.Length

                # You can upload the entire file, or split the file into multiple byte ranges, as long as the maximum bytes in any given request is less than 60 MiB
                # Uploads 42MiB each chunck
                $partSizeBytes = 320 * 1024 * 128
                $index = 0
                $start = 0
                $end = 0

                $maxloops = [Math]::Round([Math]::Ceiling($fileLength / $partSizeBytes))

                while ($fileLength -gt ($end + 1)) {
                    $start = $index * $partSizeBytes
                    if (($start + $partSizeBytes - 1 ) -lt $fileLength) {
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
                    Invoke-WebRequest -Uri $($uploadSessionUri.uploadUrl) -Headers $headers -Method PUT -Body $body -UseBasicParsing | Out-Null
                    $index++
                    Write-output "Percentage Complete: $([Math]::Ceiling($index/$maxloops*100)) %"
                }

                Write-output "File [$SourcePath] uploaded to destination [$($LibraryURL + "/" + $DestinationPath)]."
            }
            else {
                # No specific DestinationPath specified file need to be uploaded in root
                Write-output "No DestinationPath specified continue process root [$LibraryURL]."

                Write-output "Creating an upload session..."
                $Uri = "https://graph.microsoft.com/v1.0/drives/$($DriveId)/items/root:/$($FileName):/createUploadSession"
                $uploadSessionUri = Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method POST

                Write-output "Getting local file [$sourcePath]."
                $fileInBytes = [System.IO.File]::ReadAllBytes($sourcePath)
                $fileLength = $fileInBytes.Length

                # You can upload the entire file, or split the file into multiple byte ranges, as long as the maximum bytes in any given request is less than 60 MiB
                # Uploads 42MiB each chunck
                $partSizeBytes = 320 * 1024 * 128
                $index = 0
                $start = 0
                $end = 0

                $maxloops = [Math]::Round([Math]::Ceiling($fileLength / $partSizeBytes))

                while ($fileLength -gt ($end + 1)) {
                    $start = $index * $partSizeBytes
                    if (($start + $partSizeBytes - 1 ) -lt $fileLength) {
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
                    Invoke-WebRequest -Uri $($uploadSessionUri.uploadUrl) -Headers $headers -Method PUT -Body $body -UseBasicParsing | Out-Null
                    $index++
                    Write-output "Percentage Complete: $([Math]::Ceiling($index/$maxloops*100)) %"
                }

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