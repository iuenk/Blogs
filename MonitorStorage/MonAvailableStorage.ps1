#=============================================================================================================================
# Script Name:     MonAvailableStorage.ps1
# Description:     Will check available storage on all storage accounts within Azure subscriptions.
#   
# Notes      :     Will check available storage on all storage accounts within Azure subscriptions.
#                  When a file share exceeds the defined threshold an email will be send with the details.
#                  Subscription.Read.All permission needed for the Service Principal used.
#                  Reader permission on storage accounts needed for the Service Principal used.
#                  This script is created to run in Automation Accounts but can easily be modified by changing the variables.      
#
# Created by :     Ivo Uenk
# Date       :     19-11-2025
# Version    :     1.0
#=============================================================================================================================

# Get mail variable info from Automation Account variables
$MailSender = Get-AutomationVariable -Name "EmailAutomation"
$MailRecipient = Get-AutomationVariable -Name "EmailSupport"
$Recipients = $MailRecipient.Split(",")

#region functions
function Send-Mail {

    param(
        [Parameter(Mandatory=$true)][string]$Subject,
        [Parameter(Mandatory=$true)][string]$Body,
        [Parameter(Mandatory=$true)][string]$MailSender,
	    [Parameter(Mandatory=$true)][array]$Recipients,
        [Parameter(Mandatory=$false)][array]$RecipientsCC,
        [Parameter(Mandatory=$false)][array]$Attachments
    )

    try {
        # Credentials retrieved from Automation Account credentials (change to your own credential name)
        $AutomationCredential = Get-AutomationPSCredential -Name "<YourCredentialName>"
        $tenantId = Get-AutomationVariable -Name "<YourTenantIdVariableName>"
        $clientId = $AutomationCredential.UserName
        $securePassword = $AutomationCredential.Password 
        $secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)))

        # Build authentication token
        $tokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = "https://graph.microsoft.com/.default"
            Client_Id     = $clientId
            Client_Secret = $secret
        }

        $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody
        $headers = @{
            "Authorization" = "Bearer $($tokenResponse.access_token)"
            "Content-type"  = "application/json"
        }

        # Get File Name and Base64 string
        if (-not(!$Attachment)){
            $FileName=(Get-Item -Path $Attachment).name
            $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Attachment))
        }

        ############# Mail body #############
        $jsonData = @{
            message = @{
                subject = $Subject
                body = @{
                    contentType = "HTML"
                    content = $Body
                }
                toRecipients = @()
                ccRecipients = @()
                attachments = @()
            }
            saveToSentItems = $false
        }

        ############# Mail attachment #############
        if (-not(!$Attachments)){
            foreach ($Attachment in $Attachments){

                $FileName =(Get-Item -Path $Attachment).name
                $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Attachment))
                $jsonDataAdd = @{
                    '@odata.type' = "microsoft.graph.fileAttachment"
                    name = $FileName
                    contentType = "text/plain"
                    contentBytes = $base64string
                }
                $jsonData.message.Attachments += $jsonDataAdd
            }
        }

        ############# recipients #############
        foreach ($recipient in $Recipients){

            $JsonDataAdd = @{
                emailAddress = @{
                    address = $Recipient
                }
            }
            
            $jsonData.message.toRecipients += $jsonDataAdd
        }

        ############# recipientsCC #############
        if (-not(!$RecipientsCC)){
            foreach ($recipientCC in $RecipientsCC){

                $JsonDataAdd = @{
                    emailAddress = @{
                        address = $RecipientCC
                    }
                }

                $jsonData.message.RecipientsCC += $jsonDataAdd
            }
        }

        ############# update JSON and send mail #############
        $updatedJsonData = $JsonData | ConvertTo-Json -Depth 4

        $uri = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
        Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $updatedJsonData
    }
    catch {
        $Message = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($Null -eq $Message) { $Message = $($_.Exception.Message) }
        throw $Message
    }
}

function GenAzureToken {
    try {
        # Credentials retrieved from Automation Account credentials (change to your own credential name)
        $AutomationCredential = Get-AutomationPSCredential -Name "<YourCredentialName>"
        $tenantId = Get-AutomationVariable -Name "<YourTenantIdVariableName>"
        $clientId = $AutomationCredential.UserName
        $clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AutomationCredential.Password)))

        $tokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = "https://management.azure.com/.default"
            Client_Id     = $clientId
            Client_Secret = $clientSecret
        }

        $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody
        $global:headers = @{
            "Authorization" = "Bearer $($tokenResponse.access_token)"
            "Content-type"  = "application/json"
        }
        return $global:headers
    }
    catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
    }
}
#endregion functions

#region main logic
try {
    # Variables
    $percentage = '80' # Percentage of used storage to trigger alert

    # Call function to generate Azure token
    GenAzureToken

    # Get all subscriptions in the tenant
    $uri = "https://management.azure.com/subscriptions?api-version=2022-12-01"
    $Subscriptions = (Invoke-RestMethod -Uri $uri -Headers $($global:headers) -Method GET).value

    $critShares = @()

    # Get all storage accounts in each subscription
    foreach ($Sub in $Subscriptions){
        # List storage accounts in the current subscription and only keep ones with a file endpoint
        $uri = "https://management.azure.com/subscriptions/$($Sub.subscriptionId)/providers/Microsoft.Storage/storageAccounts?api-version=2021-09-01"
        $stAccounts = ((Invoke-RestMethod -Uri $uri -Headers $($global:headers) -Method GET).value | `
        Where-Object {$_.properties -and $_.properties.primaryEndpoints -and $_.properties.primaryEndpoints.file})

        # Check each storage account for file shares
        foreach ($st in $stAccounts){

            # Get all file shares (handle pagination)
            $apiVersion = "2023-04-01"
            $uri = "https://management.azure.com$($st.id)/fileServices/default/shares?api-version=$apiVersion"
            $shares = @()

            do {
                $resp = Invoke-RestMethod -Uri $uri -Headers $($global:headers) -Method GET
                if ($resp.value) { $shares += $resp.value }
                $uri = if ($resp.nextLink) { $resp.nextLink } else { $null }
            } while ($uri)

            # Add each fileshare to the result list when threshold is exceeded
            foreach ($fileshare in $shares){
                # Check provisioned storage (GiB)
                $quota = 0
                if ($($fileshare.properties) -and $($fileshare.properties.shareQuota)){
                    $quota = [int64]$($fileshare.properties.shareQuota)
                }

                # Check current used storage capacity (GiB)
                $usage = 0
                $percentageUsed = 0
                $apiVersion = "2025-06-01"
                $uri = "https://management.azure.com$($fileshare.id)?api-version=$apiVersion&`$expand=stats"
                $usage = (Invoke-RestMethod -Uri $uri -Headers $($global:headers) -Method GET).properties.shareUsageBytes
                $usageGB = [math]::round($usage / 1024 / 1024 / 1024)
                $percentageUsed = [math]::Round($usageGB / $quota * 100,2)

                if ($percentageUsed -gt $percentage){
                    # Add custom object for the fileshare when $percentage is exceeded
                    $obj = [pscustomobject]@{
                        Name                = $($fileshare.name)
                        Sub                 = $($Sub.displayName)
                        Id                  = $($fileshare.id)
                        PrimaryLocation     = $($st.properties.primaryLocation)
                        'Quota GB'          = $quota
                        'usage GB'          = $usageGB
                        'Percentage Used'   = $percentageUsed
                    }

                    Write-Output "File share [$($fileshare.name)] in Storage Account [$($st.name)] Subscription [$($Sub.displayName)] has used [$usageGB] GB out of [$quota] GB [$percentageUsed] used."
                    Write-Output "Add file share [$($fileshare.name)] to critical list."
                    $critShares += $obj | select-object Name, Sub, Id, PrimaryLocation, 'Quota GB', 'usage GB', 'Percentage Used'
                }
                else {
                    Write-Output "File share [$($fileshare.name)] in Storage Account [$($st.name)] Subscription [$($Sub.displayName)] has used [$usageGB] GB out of [$quota] GB [$percentageUsed] used."
                }
            }
        }
    }

    # Create the mail template
    if ($critShares){
        Write-output "[$($critShares.count)] shares found that exceed the threshold."

        # Set the style for the email
        $CSS = @"
        <caption>File shares that reached the 80% depleted threshold</caption>
        <style>
        table, th, td {
        border: 1px solid black;
        border-collapse: collapse;
        }
        th, td {
        padding: 5px;
        }
        th {
        text-align: left;
        }
        </style>
"@

        $body = $critShares

        # Format content to be able to use it as body for send-mail
        $Content = $Body | ConvertTo-Html | Out-String
        $Content = $Content.Trim('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">')
        $Content = $Content.Replace('<html xmlns="http://www.w3.org/1999/xhtml">', '<html>')
        $Content = $content.Replace("<title>HTML TABLE</title>", $CSS)

        $Subject = "Storage threshold exceeded"
        Send-Mail -Recipients $Recipients -Subject $Subject -Body $Content -MailSender $MailSender
    }
    else {
        Write-Output "No shares found that exceed the threshold."
    }
}
catch {
    write-host $_.Exception.Message -f Red
    write-host $_.Exception.ItemName -f Red
    write-host
}