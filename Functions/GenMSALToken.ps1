#=============================================================================================================================
#
# Script Name:     GenMSALToken.ps1
# Description:     Build an MSAL authentication header that can be used for Microsoft Graph.
#   
# Notes      :     Import this module and address a service principal AppId and Secret. In this case retrieved from the 
#				   Azure Key vault to build an MSAL authentication header.
#
# Created by :     Ivo Uenk
# Date       :     13-9-2023
# Version    :     1.0
#=============================================================================================================================

$AutomationCredential = Get-AutomationPSCredential -Name 'AutomationCreds'
$VaultName = Get-AutomationVariable -Name "VaultName"

$userName = $AutomationCredential.UserName  
$securePassword = $AutomationCredential.Password
$psCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $securePassword 
Connect-AzAccount -Credential $psCredential -WarningAction Ignore

# Retrieve sensitive information from KeyVault
$secureClientId = (Get-AzKeyVaultSecret -VaultName $VaultName -Name clientId).SecretValue
$secureSecret = (Get-AzKeyVaultSecret -VaultName $VaultName -Name clientSecret).SecretValue
$secureTenantId = (Get-AzKeyVaultSecret -VaultName $VaultName -Name tenantId).SecretValue

# Convert KeyVault SecureString to Plaintext
$clientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureClientId)))
$secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)))
$tenantId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureTenantId)))

try {

	$connectionDetails = @{
		'TenantId'     = $tenantId
		'ClientId'     = $clientId
		'ClientSecret' = $secret | ConvertTo-SecureString -AsPlainText -Force
	}

	# Acquire a token as demonstrated in the previous examples
	$token = Get-MsalToken @connectionDetails

	$authHeader = @{
		'Authorization' = $token.CreateAuthorizationHeader()
	}
	return $authHeader
}
Catch {
	write-host $_.Exception.Message -f Red
	write-host $_.Exception.ItemName -f Red
	write-host
	break
}