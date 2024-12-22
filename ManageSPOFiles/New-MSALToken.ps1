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
	$global:token = Get-MsalToken @connectionDetails

	$global:authHeader = @{
		'Authorization' = $global:token.CreateAuthorizationHeader()
	}
	return $global:authHeader
}
Catch {
	write-host $_.Exception.Message -f Red
	write-host $_.Exception.ItemName -f Red
	write-host
	break
}