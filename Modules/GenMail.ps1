#=============================================================================================================================
#
# Script Name:     GenMail.ps1
# Description:     Can be used to send email from another script.
#   
# Notes      :     Import this module and fill the parameters to send your data.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

Function Send-Mail {

    param(
        [Parameter(Mandatory=$true)][string]$Subject,
        [Parameter(Mandatory=$true)][string]$Body, # email content
        [Parameter(Mandatory=$true)][string]$MailSender,
	    [Parameter(Mandatory=$true)][array]$Recipients, # must always be an array example recipients = @("address")
        [Parameter(Mandatory=$false)][array]$RecipientsCC, # must always be an array example recipients = @("address")
        [Parameter(Mandatory=$false)][array]$Attachments # must always be an array example attachments = @($attachment1, $attachment2)
    )

    # Retrieve data from Azure Automation account credentials and variables
    $AutomationCredential = Get-AutomationPSCredential -Name 'AutomationCreds'
    $VaultName = Get-AutomationVariable -Name 'VaultName'

    $userName = $AutomationCredential.UserName  
    $securePassword = $AutomationCredential.Password
    $psCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $securePassword 
    Connect-AzAccount -Credential $psCredential

    # Retrieve sensitive data from KeyVault
    $secureClientId = (Get-AzKeyVaultSecret -VaultName $VaultName -Name mailappId).SecretValue
    $secureSecret = (Get-AzKeyVaultSecret -VaultName $VaultName -Name mailappSecret).SecretValue
    $secureTenantId = (Get-AzKeyVaultSecret -VaultName $VaultName -Name tenantId).SecretValue

    # Convert KeyVault SecureString to Plaintext
    $clientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientId)))
    $secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)))
    $tenantId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureTenantId)))

    # Build authentication token
    try {
        $tokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = "https://graph.microsoft.com/.default"
            Client_Id     = $clientId
            Client_Secret = $secret
        }

        $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody
        $authHeader = @{
            "Authorization" = "Bearer $($tokenResponse.access_token)"
            "Content-type"  = "application/json"
        }
    }
    Catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    }

    # Get File Name and Base64 string
    if (-not(!$Attachment)){
        $FileName=(Get-Item -Path $Attachment).name
        $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Attachment))
    }

############# Mail body #############
$JsonData = @"
{
    "message": {
        "subject": "$Subject",
        "body": {
        "contentType": "HTML",
        "content": "$Body"
        },
        "toRecipients": [
        ],
        "ccRecipients": [
        ],
        "attachments": [
        ]
    },
    "saveToSentItems": "false"
}
"@ | ConvertFrom-JSON

    ############# Mail attachment #############
    if (-not(!$Attachments)){
        foreach ($Attachment in $Attachments){
            try {
                $FileName =(Get-Item -Path $Attachment).name
                $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Attachment))

$JsonDataAdd = @"
{
    "@odata.type": "microsoft.graph.fileAttachment",
    "name": "$FileName",
    "contentType": "text/plain",
    "contentBytes": "$base64string"
}
"@

                ($JsonData + ($JsonData.message.attachments += (ConvertFrom-Json $JsonDataAdd)))
            }
            catch {}
        }
    }

    ############# recipients #############
    foreach ($recipient in $Recipients){
        try {

$JsonDataAdd = @"
    {
		"emailAddress": {
        "address": "$recipient"
        }
    }
"@

            ($JsonData + ($JsonData.message.toRecipients += (ConvertFrom-Json $JsonDataAdd)))
        }
        catch {}
    }

    ############# recipientsCC #############
    if (-not(!$RecipientsCC)){
        foreach ($recipientCC in $RecipientsCC){
            try {

$JsonDataAdd = @"
    {
        "emailAddress": {
        "address": "$recipientCC"
        }
    }
"@

                ($JsonData + ($JsonData.message.ccRecipients += (ConvertFrom-Json $JsonDataAdd)))
            }
            catch {}
        }
    }

    ############# update JSON and send mail #############
    $updatedJsonData = $JsonData | ConvertTo-Json -Depth 4

    $uri = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
    Invoke-RestMethod -Method POST -Uri $uri -Headers $authHeader -Body $updatedJsonData
}