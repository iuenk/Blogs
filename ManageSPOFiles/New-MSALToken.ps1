# Convert KeyVault SecureString to Plaintext
$clientId = "<clientId>"
$secret = "<clientSecret>"
$tenantId = "<tenantId>"

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