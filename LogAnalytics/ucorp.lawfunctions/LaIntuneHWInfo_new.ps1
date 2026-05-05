
#Requires -Module ucorp.lawfunctions

# Authentication token is generated using the appId and appSecret of an AAD App registration with permissions to read Intune data and write to Log Analytics workspace.
# The script retrieves the list of all Intune managed devices and their hardware information, then uploads this data to a custom table in Log Analytics using the Data Collector API (will be deprecated in the future).

# Get data to generate access token for Graph API
$AutomationCredential = Get-AutomationPSCredential -Name "DevOpsSP"
$TenantId = Get-AutomationVariable -Name "TenantId"
$AppId = $AutomationCredential.UserName
$securePassword = $AutomationCredential.Password

$AppSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
$Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

$TableName = "IntuneHWInfo"
$DcrName = "Dcr" + $TableName

#Main
Write-output "getting list of all Intune Object ID's"
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id"
$Response = (Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get)
$content = $Response.value
$NextLink = $Response."@odata.nextLink"
    while ($null -ne $Nextlink){
        $Response = (Invoke-RestMethod -Uri $NextLink -Headers $Headers -Method Get)
        $NextLink = $Response."@odata.nextLink"
        $Content += $Response.value
    }

Write-Output "Gathered list of $($content.count) objects. Proceeding to retrieve hardware information for each individually..."

$intuneHWInfo = New-Object System.Collections.ArrayList
$content | ForEach-Object {
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices(`'$($_.id)`')?`$select=hardwareinformation"
        $data = (Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get)
        [void]$intuneHWInfo.add($data.hardwareInformation)
    } catch {
        Write-output "Error retrieving hw info for $($_.id)"
    }
}

# Truncate the value to 60 characters to ensure it is accepted by the Log Ingest API
$intuneHWInfo = $intuneHWInfo | ForEach-Object {
    $newObject = @{}
    foreach ($entry in $_.PSObject.Properties) {
        if ($entry.Name.Length -gt 60){
            Write-Warning "[$($entry.Name)] is longer than 60 characters. This will cause the Log Ingest API to reject the data and disable the DCR until the value is fixed." 

            # Rename the property to the truncated value to ensure it is accepted by the Log Ingest API
            $newObject[$entry.Name.Substring(0, 60)] = $entry.Value

            Write-Warning "Old value: [$($entry.Name)] New value: [$($entry.Name.Substring(0, 60))]"
        }
        else {
            $newObject[$entry.Name] = $entry.Value
        }
    }
    [PSCustomObject]$newObject
}

$DataVariable = $intuneHWInfo

# Endpoint sends data directly to DCR endpoint, so we need to get the DCR details to get the endpoint and immutable id for the DCR
$DcrDetails = Get-LawDcrDetails -DcrName $DcrName -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

# Send data to Log Analytics using the DCR
Set-LawIngestCustomLogDcr -DcrEndpoint $DcrDetails.DcrEndPointUri -DcrImmutableId $DcrDetails.DcrImmutableId `
-TableName $TableName -DcrStream $DcrDetails.DcrStream -Data $DataVariable -BatchAmount $BatchAmount `
-AppId $AppId -AppSecret $AppSecret -TenantId $TenantId