# Authentication token is generated using the appId and appSecret of an AAD App registration with permissions to read Intune data and write to Log Analytics workspace.
# The script retrieves the list of all Intune managed devices and their hardware information, then uploads this data to a custom table in Log Analytics using the Data Collector API (will be deprecated in the future).

# Get data to generate access token for Graph API
$AutomationCredential = Get-AutomationPSCredential -Name "DevOpsSP"
$TenantId = Get-AutomationVariable -Name "TenantId"
$AppId = $AutomationCredential.UserName
$securePassword = $AutomationCredential.Password

$AppSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
$Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

$ApLogName = "IntuneHWInfo"
$Date = (Get-Date)

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
# DO NOT DELETE THIS VARIABLE. Recommened keep this blank. 
$TimeStampField = ""


function Send-LogAnalyticsData() {
    param(
        [string]$sharedKey,
        [array]$body, 
        [string]$logType,
        [string]$customerId
    )

    #Defining method and datatypes
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    #Construct authorization signature
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $signature = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
    
    #Construct uri 
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
    
    #validate that payload data does not exceed limits
    if ($body.Length -gt (31.9 *1024*1024)){
        throw("Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: " + ($body.Length/1024/1024).ToString("#.#") + "Mb")
    }
    
    $payloadsize = ("Upload payload size is " + ($body.Length/1024).ToString("#.#") + "Kb ")
    
    #Create authorization Header
    $logheaders = @{
        "Authorization"        = $signature;
        "Log-Type"             = $logType;
        "x-ms-date"            = $date;
        "time-generated-field" = $TimeStampField;
    }
    #Sending data to log analytics 
    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $logheaders -Body $body -UseBasicParsing
    $statusmessage = "$($response.StatusCode) : $($payloadsize)"
    return $statusmessage 
}

#Main
Write-output "getting list of all Intune Object ID's"
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id"
$Response = (Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get)
$content = $Response.value
$NextLink = $Response."@odata.nextLink"
    while ($null -ne $Nextlink) {
        $Response = (Invoke-RestMethod -Uri $NextLink -Headers $Headers -Method Get)
        $NextLink = $Response."@odata.nextLink"
        $Content += $Response.value
    }

$Result = New-Object System.Collections.ArrayList
$content | ForEach-Object {
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices(`'$($_.id)`')?`$select=hardwareinformation"
        $data = (Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get)
        [void]$result.add($data.hardwareInformation)
    } 
    catch {
        Write-output "Error retrieving hw info for $($_.id)"
    }
}

$batchSize = 3000
$batchNum = 0
$row = 0

while ($row -lt $result.Count) {
    $batch = $result[$row..($row + $batchSize - 1)]
    $batchJson = ConvertTo-Json $batch
    
    try {
        # Submit the data to the API endpoint
        $ResponseApInventory = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($batchJson)) -logType $ApLogName
        
        #Report back status
        $date = Get-Date -Format "dd-MM HH:mm"
        $OutputMessage = "InventoryDate:$date "
            
        if ($ResponseApInventory -match "200 :") {
            $OutputMessage = $OutPutMessage + " IntuneHWInfoInventory:OK " + $ResponseApInventory
        } else {
            $OutputMessage = $OutPutMessage + " IntuneHWInfoInventory:Fail "
        }
                            
        Write-Output $OutputMessage   

        $row += $batchSize
        $batchNum++
    } 
    catch {
        Write-Output "Error uploading batch to Log Analytics"
    }
}