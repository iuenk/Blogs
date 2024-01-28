#=============================================================================================================================
#
# Script Name:     CheckCPCLicThreshold.ps1
# Description:     Will check if there are enough Windows 365 Cloud PC licenses.
#   
# Notes      :     When SKUThreshold is met a mail will be send to IT.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

. .\GenMSALToken.ps1
. .\GenMail.ps1

$W365LicenseSkus = @(
    [PSCustomObject]@{
        SKUShortname = 'CPC_E_2C_4GB_256GB';
        SKULongName = 'Windows 365 Enterprise 2 vCPU, 4 GB, 256 GB';
        SKUThreshold = 10
    },
    [PSCustomObject]@{
        SKUShortname = 'CPC_E_2C_8GB_256GB';
        SKULongName = 'Windows 365 Enterprise 2 vCPU, 8 GB, 256 GB';
        SKUThreshold = 10
    },
    [PSCustomObject]@{
        SKUShortname = 'CPC_E_2C_4GB_128GB';
        SKULongName = 'Windows 365 Enterprise 2 vCPU, 4 GB, 128 GB';
        SKUThreshold = 10
    },
    [PSCustomObject]@{
        SKUShortname = 'CPC_E_2C_8GB_128GB';
        SKULongName = 'Windows 365 Enterprise 2 vCPU, 8 GB, 128 GB';
        SKUThreshold = 50
    },
    [PSCustomObject]@{
        SKUShortname = 'CPC_E_4C_16GB_128GB';
        SKULongName = 'Windows 365 Enterprise 4 vCPU, 16 GB, 128 GB';
        SKUThreshold = 5
    }
)

Write-Output -InputObject "Attempting to retrieve License Skus"

Try {
    $uri = 'https://graph.microsoft.com/v1.0/subscribedSkus'
    $LicenseResponse = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
    }
Catch {
    Write-Error "Error with Graph query"
    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break 
}
    
ForEach ($W365License in $W365LicenseSkus) {
    Try {
        $actualLicense = $LicenseResponse | Where-Object {$_.SkuPartNumber -match $W365License.SKUShortname}
        $AvailableLicenses = ($($ActualLicense.prepaidUnits.enabled) - $($ActualLicense.consumedUnits))
        $W365License | Add-Member -MemberType NoteProperty -Name "AvailableLicenses" -Value $AvailableLicenses -Force
    } Catch{
        Write-Error "Error in step to add AvailableLicense counts to collection."
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    }
    Write-output $W365License.$AvailableLicenses
}

$Issue = $false
ForEach ($W365License in $W365LicenseSkus) {
    write-output "$($W365License.Availablelicenses) vs $($W365License.SKUThreshold)"
    If ($W365License.AvailableLicenses -le $W365License.SKUThreshold) {
        $Issue = $true
    }
}

$String = $W365LicenseSkus | Out-String

$String | out-file "$ENV:temp\CheckLicThreshold.txt"
$Attachments = @(
    "$ENV:temp\CheckLicThreshold.txt"
)

If ($Issue -eq $False) {
    Write-Output "All license counts within Thresholds"
} ElseIf ($Issue -eq $true){
    #send email with details
    Write-output "License count for one or more W365 licenses is below Threshold. Sending mail."
    $Recipient = Get-AutomationVariable -Name "MailRecipient"
    $Recipients = $Recipient.Split(",")
    $RecipientCC = Get-AutomationVariable -Name "MailRecipient"
    $RecipientsCC = $RecipientCC.Split(",")
    $MailSender = Get-AutomationVariable -Name "MailSender"
    $Subject = "ALERT: W365License count below Threshold!"
    $body = "See below for current available license counts and take required actions:<br><br>
    $($W365licenseSkus[0].SKULongName) has $($W365licenseSkus[0].AvailableLicenses) licenses available<br>
    $($W365licenseSkus[1].SKULongName) has $($W365licenseSkus[1].AvailableLicenses) licenses available<br>
    $($W365licenseSkus[2].SKULongName) has $($W365licenseSkus[2].AvailableLicenses) licenses available<br>
    $($W365licenseSkus[3].SKULongName) has $($W365licenseSkus[3].AvailableLicenses) licenses available<br>
    $($W365licenseSkus[4].SKULongName) has $($W365licenseSkus[4].AvailableLicenses) licenses available<br>
    <br>Kind regards,<br>CMW Squad Automation"

    Send-Mail -Recipients $Recipients -recipientscc $RecipientsCC -attachments $Attachments -Subject $Subject -Body $Body -MailSender $MailSender
}