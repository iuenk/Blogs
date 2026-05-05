function Get-LawAccessToken {
  <#
    .SYNOPSIS
    Get access token for connecting management.azure.com - used for REST API connectivity.

    .DESCRIPTION
    Can be used under current connected user - or by Azure app connectivity with secret.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Get-LawAccessToken -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id"
 #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    if (($AppId) -and ($AppSecret) -and ($TenantId)){
        $AccessTokenUri = 'https://management.azure.com/'
        $oAuthUri       = "https://login.microsoftonline.com/$($TenantId)/oauth2/token"
        $authBody       = [Ordered] @{
            resource = $AccessTokenUri
            client_id = $AppId
            client_secret = $AppSecret
            grant_type = 'client_credentials'
        }
        $authResponse = invoke-restmethod -UseBasicParsing -Method Post -Uri $oAuthUri -Body $authBody -ErrorAction Stop
        $token = $authResponse.access_token

        # Set the WebRequest headers
        $Headers = @{
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
            'Authorization' = "Bearer $token"
        }
    }
    return [array]$Headers
}

function Get-LawObjectSchemaAsArray {
  <#
    .SYNOPSIS
    Gets the schema of the object as array with column-names and their type (string, boolean, dynamic, etc.).

    .DESCRIPTION
    Used to validate the data structure - and give insight of any potential data manipulation.

    .PARAMETER Data
    The data to be validated.

    .PARAMETER ReturnType
    The return type of the schema, either in LogAnalytics table-format or DCR-format.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Get-LawObjectSchemaAsArray -Data $data -ReturnType "Table"
  #>

    [CmdletBinding()]
    param(
      [Parameter(mandatory)]
      [Array]$Data,
      [Parameter()]
      [ValidateSet("Table", "DCR")]
      [string[]]$ReturnType
    )

    $SchemaArrayLogAnalyticsTableFormat = @()
    $SchemaArrayDcrFormat = @()
    $SchemaArrayLogAnalyticsTableFormatHash = @()
    $SchemaArrayDcrFormatHash = @()

    # Requirement - Add TimeGenerated to array
    $SchemaArrayLogAnalyticsTableFormatHash += @{
        name        = "TimeGenerated"
        type        = "datetime"
        description = ""
    }

    $SchemaArrayLogAnalyticsTableFormat += [PSCustomObject]@{
        name        = "TimeGenerated"
        type        = "datetime"
        description = ""
    }

    # Loop source object and build hash for table schema
    foreach ($Entry in $Data){
        $ObjColumns = $Entry | ConvertTo-Json -Depth 100 | ConvertFrom-Json | Get-Member -MemberType NoteProperty
        foreach ($Column in $ObjColumns){

            $ObjDefinitionStr = $Column.Definition
                If ($ObjDefinitionStr -like "int*")                                            { $ObjType = "int" }
            ElseIf ($ObjDefinitionStr -like "real*")                                           { $ObjType = "int" }
            ElseIf ($ObjDefinitionStr -like "long*")                                           { $ObjType = "long" }
            ElseIf ($ObjDefinitionStr -like "guid*")                                           { $ObjType = "dynamic" }
            ElseIf ($ObjDefinitionStr -like "string*")                                         { $ObjType = "string" }
            ElseIf ($ObjDefinitionStr -like "datetime*")                                       { $ObjType = "datetime" }
            ElseIf ($ObjDefinitionStr -like "bool*")                                           { $ObjType = "boolean" }
            ElseIf ($ObjDefinitionStr -like "object*")                                         { $ObjType = "dynamic" }
            ElseIf ($ObjDefinitionStr -like "System.Management.Automation.PSCustomObject*")    { $ObjType = "dynamic" }

            # build for array check
            $SchemaLogAnalyticsTableFormatObjHash = @{
                name        = $Column.Name
                type        = $ObjType
                description = ""
            }

            $SchemaLogAnalyticsTableFormatObj     = [PSCustomObject]@{
                name        = $Column.Name
                type        = $ObjType
                description = ""
            }
            $SchemaDcrFormatObjHash = @{
                name        = $Column.Name
                type        = $ObjType
            }

            $SchemaDcrFormatObj     = [PSCustomObject]@{
                name        = $Column.Name
                type        = $ObjType
            }

            if ($Column.Name -notin $SchemaArrayLogAnalyticsTableFormat.name){
                $SchemaArrayLogAnalyticsTableFormat       += $SchemaLogAnalyticsTableFormatObj
                $SchemaArrayDcrFormat                     += $SchemaDcrFormatObj

                $SchemaArrayLogAnalyticsTableFormatHash   += $SchemaLogAnalyticsTableFormatObjHash
                $SchemaArrayDcrFormatHash                 += $SchemaDcrFormatObjHash
            }
        }
    }

    if ($ReturnType -eq "Table"){
        # Return schema format for LogAnalytics table
        return $SchemaArrayLogAnalyticsTableFormat
    }
    elseif ($ReturnType -eq "DCR"){
        # Return schema format for DCR
        return $SchemaArrayDcrFormat
    }
    else {
        # Return schema format for DCR
        Return $SchemaArrayDcrFormat
    } 
}

function Get-LawObjectSchemaAsHash {
  <#
    .SYNOPSIS
    Gets the schema of the object as hash table with column-names and their type (string, boolean, dynamic, etc.).

    .DESCRIPTION
    Used to validate the data structure - and give insight of any potential data manipulation.
    Support to return in both LogAnalytics table-format and DCR-format.

    .PARAMETER Data
    The data to be validated.

    .PARAMETER ReturnType
    The return type of the schema, either in LogAnalytics table-format or DCR-format.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Get-LawObjectSchemaAsHash -Data $data -ReturnType "Table"
  #>

    [CmdletBinding()]
    param(
      [Parameter(mandatory)]
      [Array]$Data,
      [Parameter(mandatory)]
      [ValidateSet("Table", "DCR")]
      [string[]]$ReturnType
    )

    $SchemaArrayLogAnalyticsTableFormat = @()
    $SchemaArrayDcrFormat = @()
    $SchemaArrayLogAnalyticsTableFormatHash = @()
    $SchemaArrayDcrFormatHash = @()

    # Requirement - Add TimeGenerated to array
    $SchemaArrayLogAnalyticsTableFormatHash += @{
        name        = "TimeGenerated"
        type        = "datetime"
        description = ""
    }

    $SchemaArrayLogAnalyticsTableFormat += [PSCustomObject]@{
        name        = "TimeGenerated"
        type        = "datetime"
        description = ""
    }

    # Loop source object and build hash for table schema
    foreach ($Entry in $Data){
        $ObjColumns = $Entry | ConvertTo-Json -Depth 100 | ConvertFrom-Json | Get-Member -MemberType NoteProperty
        foreach ($Column in $ObjColumns){
            $ObjDefinitionStr = $Column.Definition
                    if ($ObjDefinitionStr -like "int*")                                            { $ObjType = "int" }
                elseif ($ObjDefinitionStr -like "real*")                                           { $ObjType = "int" }
                elseif ($ObjDefinitionStr -like "long*")                                           { $ObjType = "long" }
                elseif ($ObjDefinitionStr -like "guid*")                                           { $ObjType = "dynamic" }
                elseif ($ObjDefinitionStr -like "string*")                                         { $ObjType = "string" }
                elseif ($ObjDefinitionStr -like "datetime*")                                       { $ObjType = "datetime" }
                elseif ($ObjDefinitionStr -like "bool*")                                           { $ObjType = "boolean" }
                elseif ($ObjDefinitionStr -like "object*")                                         { $ObjType = "dynamic" }
                elseif ($ObjDefinitionStr -like "System.Management.Automation.PSCustomObject*")    { $ObjType = "dynamic" }

                # build for array check
                $SchemaLogAnalyticsTableFormatObjHash = @{
                    name        = $Column.Name
                    type        = $ObjType
                    description = ""
                }

                $SchemaLogAnalyticsTableFormatObj     = [PSCustomObject]@{
                    name        = $Column.Name
                    type        = $ObjType
                    description = ""
                }
                $SchemaDcrFormatObjHash = @{
                    name        = $Column.Name
                    type        = $ObjType
                }

                $SchemaDcrFormatObj     = [PSCustomObject]@{
                    name        = $Column.Name
                    type        = $ObjType
                }

                if ($Column.Name -notin $SchemaArrayLogAnalyticsTableFormat.name){
                    $SchemaArrayLogAnalyticsTableFormat       += $SchemaLogAnalyticsTableFormatObj
                    $SchemaArrayDcrFormat                     += $SchemaDcrFormatObj

                    $SchemaArrayLogAnalyticsTableFormatHash   += $SchemaLogAnalyticsTableFormatObjHash
                    $SchemaArrayDcrFormatHash                 += $SchemaDcrFormatObjHash
                }
            }
        }

        if ($ReturnType -eq "Table"){
            # Return schema format for Table
            $SchemaArrayLogAnalyticsTableFormatHash
        }
        elseif ($ReturnType -eq "DCR"){
            # Return schema format for DCR
            $SchemaArrayDcrFormatHash
        }
        
        Return
}

function Get-DcrListAll {
  <#
    .SYNOPSIS
    Builds list of all Data Collection Rules (DCRs), which can be retrieved by Azure using the RBAC context of the Log Ingestion App.

    .DESCRIPTION
    Data is retrieved using Azure Resource Graph. Result is saved in global-variable in Powershell.
    Main reason for saving as global-variable is to optimize number of times to do lookup - due to throttling in Azure Resource Graph.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Get-DcrListAll -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id"
  #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    Write-Output "Getting Data Collection Rules from Azure Resource Graph .... Please Wait !"

    $Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    # Get DCRs from Azure Resource Graph
    $GraphQuery = @{
        'query' = 'Resources | where type =~ "microsoft.insights/datacollectionrules" '
    } | ConvertTo-Json -Depth 20

    $ResponseData = @()

    $GraphUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
    $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
    $ResponseData += $ResponseRaw.content
    $ResponseNextLink = $ResponseRaw."@odata.nextLink"

    while ($null -ne $ResponseNextLink){
        $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
        $ResponseData += $ResponseRaw.content
        $ResponseNextLink = $ResponseRaw."@odata.nextLink"
    }

    $DataJson = $ResponseData | ConvertFrom-Json
    $Data = $DataJson.data

    return $Data
}

function Get-LawDcrDetails {
 <#
    .SYNOPSIS
    Retrieves information about data collection rules - using Azure Resource Graph.

    .DESCRIPTION
    Used to retrieve information about data collection rules - using Azure Resource Graph.
    Used by other functions which are looking for DCR by name.

    .PARAMETER DcrName
    The name of the DCR to retrieve information about.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Get-LawDcrDetails -DcrName "your-dcr-name" -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id"
 #>

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [ValidatePattern('^[a-zA-Z0-9]{3,30}$')]
        [string]$DcrName,
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    # Connection
    $Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    # Get DCRs from Azure Resource Graph
    if ($DcrName){
        $GraphQuery = @{
            'query' = 'Resources | where type =~ "microsoft.insights/datacollectionrules" '
        } | ConvertTo-Json -Depth 20

        $ResponseData = @()
        $GraphUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
        $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
        $ResponseData += $ResponseRaw.content
        $ResponseNextLink = $ResponseRaw."@odata.nextLink"

        while ($null -ne $ResponseNextLink){
            $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
            $ResponseData += $ResponseRaw.content
            $ResponseNextLink = $ResponseRaw."@odata.nextLink"
        }

        $DataJson = $ResponseData | ConvertFrom-Json
        $Data = $DataJson.data

        $DcrInfo = $Data | Where-Object {$_.name -eq $DcrName}

        if (!($DcrInfo)){
            Write-Output "Could not find DCR with name [ $($DcrName) ]"
        }
    }
    else {
        Write-Output "DCR name was not provided, skipping DCR details retrieval."
    }

    # values
    if (($DcrName) -and ($DcrInfo)){
        $customTable = [pscustomobject]@{
            DcrResourceId = $DcrInfo.id
            DcrLocation = $DcrInfo.location
            DcrEndPointUri = $DcrInfo.properties.endpoints.logsIngestion
            DcrImmutableId = $DcrInfo.properties.immutableId
            DcrStream = $DcrInfo.properties.dataflows.outputStream
            DcrDestinationsLogAnalyticsWorkSpaceName = $DcrInfo.properties.destinations.logAnalytics.name
            DcrDestinationsLogAnalyticsWorkSpaceId = $DcrInfo.properties.destinations.logAnalytics.workspaceId
            DcrDestinationsLogAnalyticsWorkSpaceResourceId = $DcrInfo.properties.destinations.logAnalytics.workspaceResourceId
            DcrTransformKql = $DcrInfo.properties.dataFlows[0].transformKql
        }

        # return / output
        $customTable
    }
    return
}

function Set-LawIngestCustomLogDcr {
 <#
    .SYNOPSIS
    Send data to LogAnalytics using Log Ingestion API and Data Collection Rule.

    .DESCRIPTION
    Data is either sent as one record (if only one exist), batches (calculated value of number of records to send per batch) - or BatchAmount (used only if the size of the records changes so you run into problems with limitations. 
    In case of diffent sizes, use 1 for BatchAmount. Sending data in UTF8 format.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .PARAMETER DcrEndpoint
    The DCR Endpoint to use for log ingestion.

    .PARAMETER DcrImmutableId
    The immutable ID of the DCR.

    .PARAMETER DcrStream
    The stream name of the DCR.

    .PARAMETER Data
    The data to be sent to LogAnalytics.

    .PARAMETER TableName
    The name of the LogAnalytics table to send data to (without _CL suffix).

    .PARAMETER BatchAmount
    The amount of records to send per batch. If not provided, the function will calculate the optimal batch size based on the size of the records and Azure limits (max 1 mb per transfer).

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Set-LawIngestCustomLogDcr -DcrEndpoint "your-dcr-endpoint" -DcrImmutableId "your-dcr-immutable-id" -DcrStream "your-dcr-stream" -Data $data -TableName "your-table-name" -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id"
#>    

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [string]$DcrEndpoint,
        [Parameter(mandatory)]
        [AllowEmptyString()]
        [string]$DcrImmutableId,
        [Parameter(mandatory)]
        [AllowEmptyString()]
        [string]$DcrStream,
        [Parameter(mandatory)]
        [Array]$Data,
        [Parameter(mandatory)]
        [string]$TableName,
        [Parameter()]
        [string]$BatchAmount,
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    # On a newly created DCR, sometimes we cannot retrieve the DCR info fast enough. So we skip trying to send in data !
    if (($null -eq $DcrImmutableId) -or ($null -eq $DcrStream) -or ($null -eq $DcrEndpoint)){
            # skipping as this is a newly created DCR. Just rerun the script and it will work !
    }
    else {
        if ($DcrEndpoint -and $DcrImmutableId -and $DcrStream -and $Data){
            # Add assembly to upload using http
            Add-Type -AssemblyName System.Web

            # Obtain a bearer token used to authenticate against the data collection endpoint using Azure App & Secret
            $scope       = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
            $bodytoken   = "client_id=$AppId&scope=$scope&client_secret=$AppSecret&grant_type=client_credentials";
            $headers     = @{"Content-Type"="application/x-www-form-urlencoded"};
            $uri         = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

            $bearerToken = (invoke-restmethod -UseBasicParsing -Uri $uri -Method "Post" -Body $bodytoken -Headers $headers).access_token

            $headers = @{
                "Authorization" = "Bearer $bearerToken";
                "Content-Type" = "application/json";
            }

            # Upload the data using Log Ingesion API using DCR
                    
            # initial variable
            $indexLoopFrom = 0

            # calculate size of data (entries)
            $TotalDataLines = ($Data | Measure-Object).count
            
            # calculate number of entries to send during each transfer - log ingestion api limits to max 1 mb per transfer
            if (($TotalDataLines -gt 1) -and (!($BatchAmount))){
                $SizeDataSingleEntryJson  = (ConvertTo-Json -Depth 100 -InputObject @($Data[0]) -Compress).length
                $DataSendAmountDecimal    = (( 1mb - 300Kb) / $SizeDataSingleEntryJson)   # 500 Kb is overhead (my experience !)
                $DataSendAmount           = [math]::Floor($DataSendAmountDecimal)
            }
            elseif ($BatchAmount){
                $DataSendAmount = $BatchAmount
            }
            else {
                $DataSendAmount = 1
            }

            # loop - upload data in batches, depending on possible size & Azure limits 
            do {
                $DataSendRemaining = $TotalDataLines - $indexLoopFrom

                if ($DataSendRemaining -le $DataSendAmount){
                    # send last batch - or whole batch
                    $indexLoopTo    = $TotalDataLines - 1   # cause we start at 0 (zero) as first record
                    $DataScopedSize = $Data   # no need to split up in batches
                }
                elseif ($DataSendRemaining -gt $DataSendAmount){
                    # data must be splitted in batches
                    $indexLoopTo    = $indexLoopFrom + $DataSendAmount
                    $DataScopedSize = $Data[$indexLoopFrom..$indexLoopTo]
                }

                # Convert data into JSON-format
                $JSON = ConvertTo-Json -Depth 100 -InputObject @($DataScopedSize) -Compress

                if ($DataSendRemaining -gt 1){    # batch
                    # we are showing as first record is 1, but actually is is in record 0 - but we change it for gui purpose
                    Write-Output "[$($indexLoopFrom + 1)..$($indexLoopTo + 1) / $($TotalDataLines)] - Posting data to LogAnalytics table [$($TableName)_CL] .... Please Wait !"
                }
                elseif ($DataSendRemaining -eq 1){   # single record
                    Write-Output "[$($indexLoopFrom + 1) / $($TotalDataLines)] - Posting data to LogAnalytics table [$($TableName)_CL] .... Please Wait !"
                }

                $uri = "$DcrEndpoint/dataCollectionRules/$DcrImmutableId/streams/$DcrStream"+"?api-version=2023-01-01"
            
                # set encoding to UTF8
                $JSON = [System.Text.Encoding]::UTF8.GetBytes($JSON)

                $Result = invoke-webrequest -UseBasicParsing -Uri $uri -Method POST -Body $JSON -Headers $headers -ErrorAction SilentlyContinue
                $StatusCode = $Result.StatusCode

                if ($StatusCode -eq "204"){
                    Write-Output "SUCCESS - data uploaded to LogAnalytics"
                }
                elseif ($StatusCode -eq "RequestEntityTooLarge"){
                    Write-Error "Error 513 - You are sending too large data - make the dataset smaller"
                }
                else {
                    Write-Error $result
                }

                # Set new Fom number, based on last record sent
                $indexLoopFrom = $indexLoopTo
            }
            Until ($IndexLoopTo -ge ($TotalDataLines - 1))
        }
        else {
            Write-Output "One or more required parameters for data upload are missing. Please check DCR Endpoint, DCR Immutable ID, DCR Stream and Data parameters."
        }
    
        #return latest upload result
        return $Result
        Write-Output ""
    }
}

function Set-LawCreateUpdateDataCollectionRuleLogIngestCustomLog {
 <#
    .SYNOPSIS
    Create or Update Azure Data Collection Rule (DCR) used for log ingestion to Azure LogAnalytics using Log Ingestion API.
    Beware delegating Monitor Metrics Publisher Role permission (ID: 3913510d-42f4-4e42-8a64-420c390055eb) to Log Ingest App registration. Set role on resource group level of the DCR.
    Merge/Migrate = Merge new properties into existing schema, Overwrite = use source object schema, Migrate = It will create the DCR, based on the schema from the LogAnalytics v1 table schema.
    $SetLogIngestApiAppPermissionsDcrLevel = $true will set the permissions on DCR level, which is more secure but also more complex to set up (as you need to have the DCR created before you can set permissions).

    .DESCRIPTION
    Uses schema based on source object.

    .PARAMETER SchemaSourceObject
    The source object used to build the schema for the DCR. Can be any object, but typically used with the original data object which is sent to LogAnalytics.

    .PARAMETER LogWorkspaceResourceId
    The resource ID of the LogAnalytics workspace where the DCR should send data to.

    .PARAMETER DcrResourceGroup
    The resource group where the DCR is or should be located.

    .PARAMETER DcrName
    The name of the DCR to create or update.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .PARAMETER TableName
    The name of the LogAnalytics table to send data to (without _CL suffix).

    .PARAMETER BatchAmount
    The amount of records to send per batch. If not provided, the function will calculate the optimal batch size based on the size of the records and Azure limits (max 1 mb per transfer).

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Set-LawCreateUpdateDataCollectionRuleLogIngestCustomLog -SchemaSourceObject $data -LogWorkspaceResourceId "your-log-analytics-resource-id" -DcrResourceGroup "your-dcr-resource-group" -DcrName "your-dcr-name" -TableName "your-table-name" -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id"
#>

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [array]$SchemaSourceObject,
        [Parameter(mandatory)]
        [string]$LogWorkspaceResourceId,
        [Parameter(mandatory)]
        [string]$DcrResourceGroup,
        [Parameter(mandatory)]
        [ValidatePattern('^[a-zA-Z0-9]{3,30}$')]
        [string]$DcrName,
        [Parameter(mandatory)]
        [string]$TableName,
        [Parameter()]
        [string]$SchemaMode = "Merge",
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    $Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    # Getting LogAnalytics Info        
    $LogWorkspaceUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "?api-version=2021-12-01-preview"
    $LogWorkspaceId = (invoke-restmethod -UseBasicParsing -Uri $LogWorkspaceUrl -Method GET -Headers $Headers).properties.customerId
    if ($LogWorkspaceId){
        Write-Output "Found required LogAnalytics info"
        Write-Output ""
    }
                
    # Build variables
    $KustoDefault = "source | extend TimeGenerated = now()"
    $StreamNameFull = "Custom-" + $TableName + "_CL"

    # streamname must be 52 characters or less
    if ($StreamNameFull.length -gt 52){
        $StreamName = $StreamNameFull.Substring(0,52)
    }
    else {
        $StreamName = $StreamNameFull
    }

    $DcrSubscription = ($LogWorkspaceResourceId -split "/")[2]
    $DcrLogWorkspaceName = ($LogWorkspaceResourceId -split "/")[-1]
    $DcrResourceId = "/subscriptions/$($DcrSubscription)/resourceGroups/$($DcrResourceGroup)/providers/microsoft.insights/dataCollectionRules/$($DcrName)"

    # Get existing DCR, if found
    $Uri = "https://management.azure.com" + "$DcrResourceId" + "?api-version=2024-03-11"
    $Dcr = $null

    try {
        $Dcr = invoke-webrequest -UseBasicParsing -Uri $Uri -Method GET -Headers $Headers
    }
    catch {}

    # DCR was NOT found (create) - or we do an Overwrite
    if ((!($Dcr) -and (($SchemaMode -eq "Overwrite") -or ($SchemaMode -eq "Merge"))) -or ($SchemaMode -eq "Overwrite")){
    
        # build initial payload to create DCR for log ingest (api) to custom logs
        if ($SchemaSourceObject.count -gt 10){
          $SchemaSourceObjectLimited = $SchemaSourceObject[0..10]
        }
        else {
            $SchemaSourceObjectLimited = $SchemaSourceObject
        }

        $DcrObject = [pscustomobject][ordered]@{
            properties = @{
                dataCollectionEndpointId = $DceResourceId
                streamDeclarations = @{
                    $StreamName = @{
                        columns = @(
                            $SchemaSourceObjectLimited
                        )
                    }
                }

                destinations = @{
                    logAnalytics = @(
                        @{ 
                            workspaceResourceId = $LogWorkspaceResourceId
                            workspaceId = $LogWorkspaceId
                            name = $DcrLogWorkspaceName
                        }
                    )
                }

                dataFlows = @(
                    @{
                        streams = @(
                            $StreamName
                        )

                        destinations = @(
                            $DcrLogWorkspaceName
                        )

                        transformKql = $KustoDefault
                        outputStream = $StreamName
                    }
                )
            }

            location = "westeurope"
            name = $DcrName
            kind = "Direct"
            type = "Microsoft.Insights/dataCollectionRules"
        }

        # create initial DCR using payload
        Write-Output "Creating/updating DCR [ $($DcrName) ] with limited payload"
        Write-Output $DcrResourceId

        $DcrPayload = $DcrObject | ConvertTo-Json -Depth 20

        $Uri = "https://management.azure.com" + "$DcrResourceId" + "?api-version=2024-03-11"
        invoke-webrequest -UseBasicParsing -Uri $Uri -Method PUT -Body $DcrPayload -Headers $Headers

        # sleeping to let API sync up before modifying
        Start-Sleep -s 5

        # build full payload to create DCR for log ingest (api) to custom logs
        $DcrObject = [pscustomobject][ordered]@{
            properties = @{
                dataCollectionEndpointId = $DceResourceId
                streamDeclarations = @{
                    $StreamName = @{
                        columns = @(
                            $SchemaSourceObject
                        )
                    }
                }

                destinations = @{
                    logAnalytics = @(
                        @{ 
                            workspaceResourceId = $LogWorkspaceResourceId
                            workspaceId = $LogWorkspaceId
                            name = $DcrLogWorkspaceName
                        }
                    )
                }

                dataFlows = @(
                    @{
                        streams = @(
                            $StreamName
                        )

                        destinations = @(
                            $DcrLogWorkspaceName
                        )

                        transformKql = $KustoDefault
                        outputStream = $StreamName
                    }
                )
            }

            location = "westeurope"
            name = $DcrName
            kind = "Direct"
            type = "Microsoft.Insights/dataCollectionRules"
        }

        # create DCR using payload
        Write-Output "Updating DCR [ $($DcrName) ] with full payload"
        Write-Output $DcrResourceId

        $DcrPayload = $DcrObject | ConvertTo-Json -Depth 20

        $Uri = "https://management.azure.com" + "$DcrResourceId" + "?api-version=2024-03-11"
        invoke-webrequest -UseBasicParsing -Uri $Uri -Method PUT -Body $DcrPayload -Headers $Headers

        # Try 3 times till DCR rule was found
        $retryCount = 0
        while (($null -eq $DcrRule) -and ($retryCount -lt 3)){
            $retryCount++
            Write-Output "DCR rule not found yet, retrying attempt $retryCount/3. Waiting 10 seconds..."
            Start-Sleep -Seconds 10

            # Updating DCR list using Azure Resource Graph due to new DCR was created
            $GraphQuery = @{
                'query' = 'Resources | where type =~ "microsoft.insights/datacollectionrules" '
            } | ConvertTo-Json -Depth 20

            $ResponseData = @()
            $GraphUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
            $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
            $ResponseData += $ResponseRaw.content
            $ResponseNextLink = $ResponseRaw."@odata.nextLink"

            While ($null -ne $ResponseNextLink){
                $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
                $ResponseData += $ResponseRaw.content
                $ResponseNextLink = $ResponseRaw."@odata.nextLink"
            }

            $DataJson = $ResponseData | ConvertFrom-Json
            $DcrDetails = $DataJson.data
            $DcrRule = $DcrDetails | where-Object {$_.name -eq $DcrName}
        }

        if ($DcrRule){
            Write-Output "DCR [$($DcrName)] created successfully"
        }
        else {
            Write-Error "Failed to create DCR [$($DcrName)]. Please check the logging in the Azure portal for more details."
        }
    }

    # DCR was found - we will do either a MERGE or OVERWRITE
    elseif (($Dcr) -and ($SchemaMode -eq "Merge")){

        $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($TableName)_CL?api-version=2021-12-01-preview"
        $TableStatus = try {
            invoke-restmethod -UseBasicParsing -Uri $TableUrl -Method GET -Headers $Headers
        }
        catch {}

        if ($TableStatus){
            $CurrentTableSchema = $TableStatus.properties.schema.columns
            $AzureTableSchema   = $TableStatus.properties.schema.standardColumns
        }

        # start by building new schema hash, based on existing schema in LogAnalytics custom log table
        $SchemaArrayDCRFormatHash = @()
        foreach ($Property in $CurrentTableSchema){
            $Name = $Property.name
            $Type = $Property.type

            # Add all properties except TimeGenerated as it only exist in tables - not DCRs
            if ($Name -ne "TimeGenerated"){
                $SchemaArrayDCRFormatHash += @{
                    name        = $name
                    type        = $type
                }
            }
        }
                
        # Add specific Azure column-names, if found as standard Azure columns (migrated from v1)
        $LAV1StandardColumns = @("Computer","RawData")
        foreach ($Column in $LAV1StandardColumns){
            if (($Column -notin $SchemaArrayDCRFormatHash.name) -and ($Column -in $AzureTableSchema.name)){
                $SchemaArrayDCRFormatHash += @{
                    name        = $column
                    type        = "string"
                }
            }
        }

        # get current DCR schema
        $DcrInfo = $DcrDetails | Where-Object { $_.name -eq $DcrName }

        $StreamDeclaration = 'Custom-' + $TableName + '_CL'
        $CurrentDcrSchema = $DcrInfo.properties.streamDeclarations.$StreamDeclaration.columns

        # enum $CurrentDcrSchema - and check if it exists in $SchemaArrayDCRFormatHash (coming from LogAnalytics)
        $UpdateDCR = $False
        foreach ($Property in $SchemaArrayDCRFormatHash){
            $Name = $Property.name
            $Type = $Property.type

            # Skip if name = TimeGenerated as it only exist in tables - not DCRs
            if ($Name -ne "TimeGenerated"){
                $ChkDcrSchema = $CurrentDcrSchema | Where-Object { ($_.name -eq $Name) }
                if (!($ChkDcrSchema)){
                    # DCR must be updated, changes was detected !
                    $UpdateDCR = $true
                }
            }
        }

        # Merge: build full payload to create DCR for log ingest (api) to custom logs
        if ($UpdateDCR -eq $true){
            $DcrObject = [pscustomobject][ordered]@{
                properties = @{
                    dataCollectionEndpointId = $DceResourceId
                    streamDeclarations = @{
                        $StreamName = @{
                            columns = @(
                                $SchemaArrayDCRFormatHash
                            )
                        }
                    }

                    destinations = @{
                        logAnalytics = @(
                            @{ 
                                workspaceResourceId = $LogWorkspaceResourceId
                                workspaceId = $LogWorkspaceId
                                name = $DcrLogWorkspaceName
                            }
                        )
                    }

                    dataFlows = @(
                        @{
                            streams = @(
                                $StreamName
                            )
                            destinations = @(
                                $DcrLogWorkspaceName
                            )

                            transformKql = $KustoDefault
                            outputStream = $StreamName
                        }
                    )
                }

                location = "westeurope"
                name = $DcrName
                kind = "Direct"
                type = "Microsoft.Insights/dataCollectionRules"
            }

            # Update DCR using merged payload
            Write-Output "Merge: Updating DCR [ $($DcrName) ] with new properties in schema"
            Write-Output $DcrResourceId

            $DcrPayload = $DcrObject | ConvertTo-Json -Depth 20

            $Uri = "https://management.azure.com" + "$DcrResourceId" + "?api-version=2024-03-11"
            invoke-webrequest -UseBasicParsing -Uri $Uri -Method PUT -Body $DcrPayload -Headers $Headers
        }
    }

    # DCR was NOT found - we are in Migrate mode
    elseif (!($Dcr) -and ($SchemaMode -eq "Migrate")){
        $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($TableName)_CL?api-version=2021-12-01-preview"
        $TableStatus = try {
            invoke-restmethod -UseBasicParsing -Uri $TableUrl -Method GET -Headers $Headers
        }
        catch {}

        if ($TableStatus){
            $CurrentTableSchema = $TableStatus.properties.schema.columns
            $AzureTableSchema   = $TableStatus.properties.schema.standardColumns
        }

        # start by building new schema hash, based on existing schema in LogAnalytics custom log table
        $SchemaArrayDCRFormatHash = @()
        foreach ($Property in $CurrentTableSchema){
            $Name = $Property.name
            $Type = $Property.type

            # Add all properties except TimeGenerated as it only exist in tables - not DCRs
            if ($Name -ne "TimeGenerated"){
                $SchemaArrayDCRFormatHash += @{
                    name        = $name
                    type        = $type
                }
            }
        }
                
        # Add specific Azure column-names, if found as standard Azure columns (migrated from v1)
        $LAV1StandardColumns = @("Computer","RawData")
        foreach ($Column in $LAV1StandardColumns){
            if ( ($Column -notin $SchemaArrayDCRFormatHash.name) -and ($Column -in $AzureTableSchema.name)){
                $SchemaArrayDCRFormatHash += @{
                    name        = $column
                    type        = "string"
                }
            }
        }

        # build initial payload to create DCR for log ingest (api) to custom logs
        if ($SchemaArrayDCRFormatHash.count -gt 10){
            $SchemaSourceObjectLimited = $SchemaArrayDCRFormatHash[0..10]
        }
        else {
            $SchemaSourceObjectLimited = $SchemaArrayDCRFormatHash
        }


        $DcrObject = [pscustomobject][ordered]@{
            properties = @{
                dataCollectionEndpointId = $DceResourceId
                streamDeclarations = @{
                    $StreamName = @{
                        columns = @(
                            $SchemaSourceObjectLimited
                        )
                    }
                }

                destinations = @{
                    logAnalytics = @(
                        @{ 
                            workspaceResourceId = $LogWorkspaceResourceId
                            workspaceId = $LogWorkspaceId
                            name = $DcrLogWorkspaceName
                        }
                    )
                }

                dataFlows = @(
                    @{
                        streams = @(
                            $StreamName
                        )
                        destinations = @(
                            $DcrLogWorkspaceName
                        )

                        transformKql = $KustoDefault
                        outputStream = $StreamName
                    }
                )
            }

            location = "westeurope"
            name = $DcrName
            kind = "Direct"
            type = "Microsoft.Insights/dataCollectionRules"
        }

        # create initial DCR using payload
        Write-Output "Migration - Creating/updating DCR [ $($DcrName) ] with limited payload"
        Write-Output $DcrResourceId

        $DcrPayload = $DcrObject | ConvertTo-Json -Depth 20

        $Uri = "https://management.azure.com" + "$DcrResourceId" + "?api-version=2024-03-11"
        invoke-webrequest -UseBasicParsing -Uri $Uri -Method PUT -Body $DcrPayload -Headers $Headers

        # sleeping to let API sync up before modifying
        Start-Sleep -s 5

        # build full payload to create DCR for log ingest (api) to custom logs               
        $DcrObject = [pscustomobject][ordered]@{
            properties = @{
                dataCollectionEndpointId = $DceResourceId

                streamDeclarations = @{
                    $StreamName = @{
                        columns = @(
                            $SchemaArrayDCRFormatHash
                        )
                    }
                }

                destinations = @{
                    logAnalytics = @(
                        @{ 
                            workspaceResourceId = $LogWorkspaceResourceId
                            workspaceId = $LogWorkspaceId
                            name = $DcrLogWorkspaceName
                        }
                    )
                }

                dataFlows = @(
                    @{
                        streams = @(
                            $StreamName
                        )
                        destinations = @(
                            $DcrLogWorkspaceName
                        )

                        transformKql = $KustoDefault
                        outputStream = $StreamName
                    }
                )
            }

            location = "westeurope"
            name = $DcrName
            kind = "Direct"
            type = "Microsoft.Insights/dataCollectionRules"
        }

        # create DCR using payload
        Write-Output "Migration - Updating DCR [ $($DcrName) ] with full payload"
        Write-Output $DcrResourceId

        $DcrPayload = $DcrObject | ConvertTo-Json -Depth 20

        $Uri = "https://management.azure.com" + "$DcrResourceId" + "?api-version=2024-03-11"
        invoke-webrequest -UseBasicParsing -Uri $Uri -Method PUT -Body $DcrPayload -Headers $Headers

        # Try 3 times till DCR rule was found
        $retryCount = 0
        while (($null -eq $DcrRule) -and ($retryCount -lt 3)){
            $retryCount++
            Write-Output "DCR rule not found yet, retrying attempt $retryCount/3. Waiting 10 seconds..."
            Start-Sleep -Seconds 10

            # Updating DCR list using Azure Resource Graph due to new DCR was created
            $GraphQuery = @{
                'query' = 'Resources | where type =~ "microsoft.insights/datacollectionrules" '
            } | ConvertTo-Json -Depth 20

            $ResponseData = @()
            $GraphUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
            $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
            $ResponseData += $ResponseRaw.content
            $ResponseNextLink = $ResponseRaw."@odata.nextLink"

            While ($null -ne $ResponseNextLink){
                $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
                $ResponseData += $ResponseRaw.content
                $ResponseNextLink = $ResponseRaw."@odata.nextLink"
            }

            $DataJson = $ResponseData | ConvertFrom-Json
            $DcrDetails = $DataJson.data
            $DcrRule = $DcrDetails | where-Object {$_.name -eq $DcrName}
        }

        if ($DcrRule){
            Write-Output "DCR [$($DcrName)] created successfully"
        }
        else {
            Write-Error "Failed to create DCR [$($DcrName)]. Please check the logging in the Azure portal for more details."
        }
    }
}

function Get-LawTableDataCollectionRuleStatus {
 <#
    .SYNOPSIS
    Get status about Azure Loganalytics tables and Data Collection Rule.

    .DESCRIPTION
    Used to detect if table/DCR must be create/updated - or it is valid to send in data.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .PARAMETER DcrName
    The name of the DCR to check.

    .PARAMETER LogWorkspaceResourceId
    The resource ID of the LogAnalytics workspace where the DCR should send data to.

    .PARAMETER TableName
    The name of the LogAnalytics table to send data to (without _CL suffix).

    .PARAMETER SchemaSourceObject
    The source object used to build the schema for the DCR. Can be any object, but typically used with the original data object which is sent to LogAnalytics.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Get-LawTableDataCollectionRuleStatus -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id" -DcrName "your-dcr-name" -LogWorkspaceResourceId "your-log-analytics-resource-id" -TableName "your-table-name" -SchemaSourceObject $data
#>

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [string]$LogWorkspaceResourceId,
        [Parameter(mandatory)]
        [string]$TableName,
        [Parameter(mandatory)]
        [ValidatePattern('^[a-zA-Z0-9]{3,30}$')]
        [string]$DcrName,
        [Parameter(mandatory)]
        [array]$SchemaSourceObject,
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    Write-Output "Checking LogAnalytics table and Data Collection Rule configuration .... Please Wait!"

    # by default ($false)
    $DcrDceTableCustomLogCreateUpdate = $false # $True/$False - typically used when updates to schema detected

    $Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    # Check if Azure LogAnalytics Table exist
    $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($TableName)_CL?api-version=2021-12-01-preview"
    $TableStatus = try {
        invoke-restmethod -UseBasicParsing -Uri $TableUrl -Method GET -Headers $Headers
    }
    catch {
        Write-Output "  LogAnalytics table wasn't found !"
        # initial setup - force to auto-create structure
        $DcrDceTableCustomLogCreateUpdate = $true     # $True/$False - typically used when updates to schema detected
    }

    # Compare schema between source object schema and Azure LogAnalytics Table
    if ($TableStatus){
        $CurrentTableSchema = $TableStatus.properties.schema.columns
        $AzureTableSchema   = $TableStatus.properties.schema.standardColumns

        # Verify LogAnalytics table schema matches source object ($SchemaSourceObject) - otherwise set flag to update schema in LA/DCR
        foreach ($Entry in $SchemaSourceObject){
            $ChkSchemaCurrent = $CurrentTableSchema | Where-Object { ($_.name -eq $Entry.name) }
            $ChkSchemaStd = $AzureTableSchema | Where-Object { ($_.name -eq $Entry.name) }

            if (($null -eq $ChkSchemaCurrent) -and ($null -eq $ChkSchemaStd)){
                Write-Output "  Schema mismatch - property missing (name: $($Entry.name), type: $($Entry.type))"

                # Set flag to update schema
                $DcrDceTableCustomLogCreateUpdate = $true     # $True/$False - typically used when updates to schema detected
            }
        }
    }

    # Check if Azure Data Collection Rule exist
    # Check in global variable
    $GraphQuery = @{
        'query' = 'Resources | where type =~ "microsoft.insights/datacollectionrules" '
    } | ConvertTo-Json -Depth 20

    $ResponseData = @()
    $GraphUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
    $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
    $ResponseData += $ResponseRaw.content
    $ResponseNextLink = $ResponseRaw."@odata.nextLink"

    while ($null -ne $ResponseNextLink){
        $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
        $ResponseData += $ResponseRaw.content
        $ResponseNextLink = $ResponseRaw."@odata.nextLink"
    }

    $DataJson = $ResponseData | ConvertFrom-Json
    $Data = $DataJson.data

    $DcrInfo = $Data | Where-Object {$_.name -eq $DcrName}
    if (!($DcrInfo)){
        Write-Output "  DCR was not found [ $($DcrName) ]"
        # initial setup - force to auto-create structure
        $DcrDceTableCustomLogCreateUpdate = $true     # $True/$False - typically used when updates to schema detected
    }

    # Compare DCR schema with Table schema
    # LogAnalytics table
    $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($TableName)_CL?api-version=2021-12-01-preview"
    $TableStatus = try {
        invoke-restmethod -UseBasicParsing -Uri $TableUrl -Method GET -Headers $Headers
    }
    catch {}

    if ($TableStatus){
        $CurrentTableSchema  = $TableStatus.properties.schema.columns
        $FilteredTableSchema = $CurrentTableSchema | Where-Object {$_.name -ne "TimeGenerated" }   # this is a mandatory which only exist in LA, not DCR
        $TableSchemaPropertyAmount = ($FilteredTableSchema | Measure-Object).count
    }

    # DCR
    if ($DcrInfo){
        $StreamDeclaration = 'Custom-' + $TableName + '_CL'
        $CurrentDcrSchema = $DcrInfo.properties.streamDeclarations.$StreamDeclaration.columns
        $DcrSchemaPropertyAmount = ($CurrentDcrSchema | Measure-Object).count
    }
  
    # Compare amounts
    if ($DcrSchemaPropertyAmount -lt $TableSchemaPropertyAmount){
        Write-Output "  Schema mismatch - property missing in DCR"

        # Set flag to update schema
        $DcrDceTableCustomLogCreateUpdate = $true     # $True/$False - typically used when updates to schema detected
    }
    else {
        # start by building new schema hash, based on existing schema in LogAnalytics custom log table
        $ChangesDetected = $false
        foreach ($Property in $CurrentTableSchema){
            $Name = $Property.name
            $Type = $Property.type

            # Add all properties except TimeGenerated as it only exist in tables - not DCRs
            if ($Name -ne "TimeGenerated"){
                $ChkDcrSchema = $CurrentDcrSchema | Where-Object {($_.name -eq $Name)}
                if (!($ChkDcrSchema)){
                    $ChangesDetected = $true
                }
            }
        }

        if ($ChangesDetected -eq $true){
            Write-Output "  Schema mismatch - property missing in DCR"
            # Set flag to update schema
            $DcrDceTableCustomLogCreateUpdate = $true     # $True/$False - typically used when updates to schema detected
        }
    }

    if ($DcrDceTableCustomLogCreateUpdate -eq $false){
        Write-Output "  Success - Schema & DCR structure is OK"
    }

    return $DcrDceTableCustomLogCreateUpdate
}

function Set-LawCustomLogTableDcr {
<#
    .SYNOPSIS
    Create or Update Azure LogAnalytics Custom Log table - used together with Data Collection Rules (DCR) for Log Ingestion API upload to LogAnalytics.

    .DESCRIPTION
    Uses schema based on source object.

    .PARAMETER Tablename
    Specifies the table name in LogAnalytics.

    .PARAMETER SchemaSourceObject
    This is the schema in hash table format coming from the source object.

    .PARAMETER LogWorkspaceResourceId
    The resource ID of the LogAnalytics workspace where the DCR should send data to.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .PARAMETER SchemaMode
    SchemaMode = Merge (default). It will do a merge/union of new properties and existing schema properties. DCR will import schema from table.
    SchemaMode = Overwrite. It will overwrite existing schema in DCR/table – based on source object schema. This parameter can be useful for separate overflow work
    SchemaMode = Migrate. It will create the DCR, based on the schema from the LogAnalytics v1 table schema. This parameter is used only as part of migration away from HTTP Data Collector API to Log Ingestion API

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Set-LawCustomLogTableDcr -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id" -TableName "your-table-name" -LogWorkspaceResourceId "your-log-analytics-resource-id" -SchemaSourceObject $data
 #>

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [string]$TableName,
        [Parameter(mandatory)]
        [array]$SchemaSourceObject,
        [Parameter(mandatory)]
        [string]$LogWorkspaceResourceId,
        [Parameter()]
        [string]$SchemaMode = "Merge",
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    # Connection
    $Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    # TableCheck
    $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($TableName)_CL?api-version=2021-12-01-preview"
    $TableStatus = try {
        invoke-restmethod -UseBasicParsing -Uri $TableUrl -Method GET -Headers $Headers
    }
    catch {
        if ($SchemaMode -eq "Merge"){
            # force SchemaMode to Overwrite (create/update)
            $SchemaMode = "Overwrite"
        }
    }

    # Compare schema between source object schema and Azure LogAnalytics Table
    if ($TableStatus){
        $CurrentTableSchema = $TableStatus.properties.schema.columns
        $AzureTableSchema   = $TableStatus.properties.schema.standardColumns
    }

    # LogAnalytics Table check
    $Table = $TableName  + "_CL"    # TableName with _CL (CustomLog)

    if ($Table.Length -gt 45){
        Write-Error "ERROR - Reduce length of tablename, as it has a maximum of 45 characters (current length: $($Table.Length))"
    }

    # SchemaMode = Overwrite - Creating/Updating LogAnalytics Table based upon data source schema
    if ($SchemaMode -eq "Overwrite"){
        $tableBodyPut   = @{
            properties = @{
                schema = @{
                    name    = $Table
                    columns = @($SchemaSourceObject)
                }
            }
        } | ConvertTo-Json -Depth 10

        # create/update table schema using REST
        $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($Table)?api-version=2021-12-01-preview"

        try {
            Write-Output "Trying to update existing LogAnalytics table schema for table [ $($Table) ] in "
            Write-Output $LogWorkspaceResourceId

            invoke-webrequest -UseBasicParsing -Uri $TableUrl -Method PUT -Headers $Headers -Body $TablebodyPut
        }
        catch {
            Write-Output "Internal error 500 - recreating table"
            invoke-webrequest -UseBasicParsing -Uri $TableUrl -Method DELETE -Headers $Headers
                        
            Start-Sleep -Seconds 10      
            invoke-webrequest -UseBasicParsing -Uri $TableUrl -Method PUT -Headers $Headers -Body $TablebodyPut
        }
    }

    # SchemaMode = Merge - Merging new properties into existing schema
    if (($SchemaMode -eq "Merge") -or ($SchemaMode -eq "Migrate")){
        # start by building new schema hash, based on existing schema in LogAnalytics custom log table
        $SchemaArrayLogAnalyticsTableFormatHash = @()
        foreach ($Property in $CurrentTableSchema){
            $Name = $Property.name
            $Type = $Property.type

            if ($Name -notin $AzureTableSchema.name){   # exclude standard columns, especially important with migrated from v1 as Computer, TimeGenerated, etc. exist
                $SchemaArrayLogAnalyticsTableFormatHash += @{
                  name        = $name
                  type        = $type
                  description = ""
                }
            }
        }

        # enum $SchemaSourceObject - and check if it exists in $SchemaArrayLogAnalyticsTableFormatHash
        $UpdateTable = $False
        foreach ($PropertySource in $SchemaSourceObject){
            if ($PropertySource.name -notin $AzureTableSchema.name){   # exclude standard columns, especially important with migrated from v1 as Computer, TimeGenerated, etc. exist
                $PropertyFound = $false
                foreach ($Property in $SchemaArrayLogAnalyticsTableFormatHash){
                    # If ( ($Property.name -eq $PropertySource.name) -and ($Property.type -eq $PropertySource.type) )
                
                    if ($Property.name -eq $PropertySource.name){
                        $PropertyFound = $true
                    }
                }
                        
                if ($PropertyFound -eq $true){
                        # Name already found ... skipping
                }
                else {
                    # table must be updated, changes detected in merge-mode
                    $UpdateTable = $true

                    Write-Output "SchemaMode = Merge: Adding property $($PropertySource.name)"
                    $SchemaArrayLogAnalyticsTableFormatHash += @{
                        name        = $PropertySource.name
                        type        = $PropertySource.type
                        description = ""
                    }
                }
            }
        }

        if ($UpdateTable -eq $true){            
            # new table structure with added properties (merging)
            $tableBodyPut   = @{
                properties = @{
                    schema = @{
                        name    = $Table
                        columns = @($SchemaArrayLogAnalyticsTableFormatHash)
                    }
                }
            } | ConvertTo-Json -Depth 10

            # create/update table schema using REST
            $TableUrl = "https://management.azure.com" + $LogWorkspaceResourceId + "/tables/$($Table)?api-version=2021-12-01-preview"

            try {
                Write-Output ""
                Write-Output "Trying to update existing LogAnalytics table schema for table [ $($Table) ] in "
                Write-Output $LogWorkspaceResourceId

                invoke-webrequest -UseBasicParsing -Uri $TableUrl -Method PUT -Headers $Headers -Body $TablebodyPut
            }
            catch {
                Write-Output ""
                Write-Output "Internal error 500 - recreating table"
                invoke-webrequest -UseBasicParsing -Uri $TableUrl -Method DELETE -Headers $Headers
                    
                Start-Sleep -Seconds 10
                invoke-webrequest -UseBasicParsing -Uri $TableUrl -Method PUT -Headers $Headers -Body $TablebodyPut
            }
        }
    }
        
    return
}

function Set-LawDataCollectionRulePermissions {
 <#
    .SYNOPSIS
    Set permissions on Data Collection Rule.

    .DESCRIPTION
    Set permissions on Data Collection Rule.

    .PARAMETER LogWorkspaceResourceId
    The resource ID of the LogAnalytics workspace where the DCR should send data to.

    .PARAMETER DcrName
    The name of the DCR to set permissions on.

    .PARAMETER LogIngestServicePrincipalObjectId
    The Object ID of the Log Ingest Service Principal in Azure AD. This is used to assign the Monitor Metrics Publisher Role on the DCR, which is required for the Log Ingest API to function properly.

    .PARAMETER AppId
    The AppId to use for authentication.

    .PARAMETER AppSecret
    The AppSecret to use for authentication.

    .PARAMETER TenantId
    The TenantId to use for authentication.

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Set-LawDataCollectionRulePermissions -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id" -DcrName "your-dcr-name" -LogWorkspaceResourceId "your-log-analytics-resource-id" -LogIngestServicePrincipalObjectId "your-log-ingest-service-principal-object-id"
#>

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [string]$LogWorkspaceResourceId,
        [Parameter(mandatory)]
        [ValidatePattern('^[a-zA-Z0-9]{3,30}$')]
        [string]$DcrName,
        [Parameter()]
        [AllowEmptyCollection()]
        [string]$LogIngestServicePrincipalObjectId,
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    $Headers = Get-LawAccessToken -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

    $DcrSubscription = ($LogWorkspaceResourceId -split "/")[2]

    $GraphQuery = @{
        'query' = 'Resources | where type =~ "microsoft.insights/datacollectionrules" '
    } | ConvertTo-Json -Depth 20

    $ResponseData = @()
    $GraphUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
    $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
    $ResponseData += $ResponseRaw.content
    $ResponseNextLink = $ResponseRaw."@odata.nextLink"

    While ($null -ne $ResponseNextLink){
        $ResponseRaw = invoke-webrequest -UseBasicParsing -Method POST -Uri $GraphUri -Headers $Headers -Body $GraphQuery
        $ResponseData += $ResponseRaw.content
        $ResponseNextLink = $ResponseRaw."@odata.nextLink"
    }

    $DataJson = $ResponseData | ConvertFrom-Json
    $DcrDetails = $DataJson.data
    $DcrRule = $DcrDetails | where-Object {$_.name -eq $DcrName}

    if ($DcrRule){
        Write-Output "[$DcrName] found continue with assigning permissions for LogIngestServicePrincipalObjectId [$LogIngestServicePrincipalObjectId]"

        # Delegating Monitor Metrics Publisher Rolepermission to Log Ingest App
        $DcrRuleId = $DcrRule.id

        Write-Output "Setting Monitor Metrics Publisher Role permissions on DCR [$($DcrName)]"

        $monitorMetricsPublisherRoleId = "3913510d-42f4-4e42-8a64-420c390055eb"
        $roleDefinitionId = "/subscriptions/$($DcrSubscription)/providers/Microsoft.Authorization/roleDefinitions/$($monitorMetricsPublisherRoleId)"

        # Get assignments from data collection rule
        $roleAssignmentUri = "https://management.azure.com" + $DcrRuleId + "/providers/Microsoft.Authorization/roleAssignments?api-version=2018-07-01"
        $existingAssignments = (invoke-restmethod -UseBasicParsing -Uri $roleAssignmentUri -Method GET -Headers $Headers -ErrorAction Stop).value.properties        

        # Check for existing role assignment for the Log Ingest App (to prevent conflicts)
        $assignmentFound = $false
        $existingAssignments | ForEach-Object {
            if (($_.principalId -eq $LogIngestServicePrincipalObjectId) -and ($_.roleDefinitionId -eq $roleDefinitionId)){
                $assignmentFound = $true
                Write-Output "Existing role assignment found for Log Ingest App on DCR [$($DcrName)] assignment will be skipped"
            }
        }

        if ($assignmentFound -eq $false){
            $guid = (new-guid).guid
            $roleUrl = "https://management.azure.com" + $DcrRuleId + "/providers/Microsoft.Authorization/roleAssignments/$($Guid)?api-version=2018-07-01"
            $roleBody = @{
                properties = @{
                    roleDefinitionId = $roleDefinitionId
                    principalId      = $LogIngestServicePrincipalObjectId
                    scope            = $DcrRuleId
                }
            }
            $jsonRoleBody = $roleBody | ConvertTo-Json -Depth 6

            $result = try {
                invoke-restmethod -UseBasicParsing -Uri $roleUrl -Method PUT -Body $jsonRoleBody -headers $Headers -ErrorAction SilentlyContinue
            }
            catch {}

            if ($result){
                Write-Output "Successfully set Monitor Metrics Publisher Role permissions on DCR [ $($DcrName) ] for Log Ingest App"
            }
            else {
                Write-Error "Failed to set Monitor Metrics Publisher Role permissions on DCR [ $($DcrName) ] for Log Ingest App. Please check if the Log Ingest App Object ID is correct and has permissions to assign roles on the DCR resource."
            }
        }
    }
}

function Set-LawCheckCreateUpdateTableDcrStructure {
 <#
    .PARAMETER Tablename
    Specifies the table name in LogAnalytics.

    .PARAMETER SchemaSourceObject
    This is the schema in hash table format coming from the source object.

    .PARAMETER SchemaMode
    SchemaMode = Merge (default). It will do a merge/union of new properties and existing schema properties. DCR will import schema from table.
    SchemaMode = Overwrite. It will overwrite existing schema in DCR/table – based on source object schema. This parameter can be useful for separate overflow work.

    .PARAMETER AzLogWorkspaceResourceId
    This is the Loganaytics Resource Id.
 
    .PARAMETER DcrName
    This is name of the Data Collection Rule to use for the upload.
    Function will automatically look check in a global variable ($global:AzDcrDetails) - or do a query using Azure Resource Graph to find DCR with name.
    Goal is to find the DCR immunetable id on the DCR. Must be between 3 and 30 characters, and can only include letters and numbers (no special characters or whitespace).

    .PARAMETER DcrResourceGroup
    This is name of the resource group, where Data Collection Rules will be stored.

    .PARAMETER TableName
    This is tablename of the LogAnalytics table (and is also used in the DCR naming).

    .PARAMETER LogIngestServicePrincipalObjectId
    This is the object id of the Azure App service-principal.
    NOTE: Not the object id of the Azure app, but Object Id of the service principal (!).

    .PARAMETER SetLogIngestApiAppPermissionsDcrLevel
    True means permissions will be set on DCR level (more secure, recommended)
    FALSE means permissions will be set on subscription level (less secure, but might be necessary if DCR level permissions fail due to lack of permissions to assign roles on DCR resource).
     NOTE: If set to TRUE, the Log Ingest App must have permissions to assign roles on the DCR resource. If set to FALSE, the Log Ingest App must have permissions to assign roles on the subscription.

    .PARAMETER AzLogDcrTableCreateFromReferenceMachine
    Array with list of computers, where schema management can be done.

    .PARAMETER AzLogDcrTableCreateFromAnyMachine
    True means schema changes can be made from any computer - FALSE means it can only happen from reference machine(s).

    .NOTES
    AUTHOR   : Ivo Uenk
    CREATED  : 28/04/2026

    .EXAMPLE
    Set-LawCheckCreateUpdateTableDcrStructure -AppId "your-app-id" -AppSecret "your-app-secret" -TenantId "your-tenant-id" -TableName "your-table-name" -LogWorkspaceResourceId "your-log-analytics-resource-id" -DcrName "your-dcr-name" -DcrResourceGroup "your-dcr-resource-group" -LogIngestServicePrincipalObjectId "your-log-ingest-service-principal-object-id" -SetLogIngestApiAppPermissionsDcrLevel $true -AzLogDcrTableCreateFromReferenceMachine @("machine1","machine2") -AzLogDcrTableCreateFromAnyMachine $false
  #>

    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        [Array]$Data,
        [Parameter(mandatory)]
        [string]$LogWorkspaceResourceId,
        [Parameter(mandatory)]
        [string]$TableName,
        [Parameter(mandatory)]
        [ValidatePattern('^[a-zA-Z0-9]{3,30}$')]
        [string]$DcrName,
        [Parameter(mandatory)]
        [string]$DcrResourceGroup,
        [Parameter()]
        [AllowEmptyCollection()]
        [string]$LogIngestServicePrincipalObjectId,
        [Parameter(mandatory)]
        [boolean]$SetLogIngestApiAppPermissionsDcrLevel = $false,
        [Parameter()]
        [boolean]$LogDcrTableCreateFromAnyMachine,
        [Parameter()]
        [string]$SchemaMode = "Merge",
        [Parameter(mandatory)]
        [AllowEmptyCollection()]
        [array]$LogDcrTableCreateFromReferenceMachine,
        [Parameter()]
        [string]$AppId,
        [Parameter()]
        [string]$AppSecret,
        [Parameter()]
        [string]$TenantId
    )

    # Create/Update Schema for LogAnalytics Table & Data Collection Rule schema
    # default
    $IssuesFound = $false

    # Check for prohibited table names
    if ($TableName -like "_*"){   # remove any leading underscores - column in DCR/LA must start with a character
        $IssuesFound = $true
        Write-Output "  ISSUE - Table name must start with character [ $($TableName) ]"
    }
    elseif ($TableName -like "*-*"){   # includes - (hyphen)
      $IssuesFound = $true
      Write-Output "  ISSUE - Table name include - (hyphen) - must be removed [ $($TableName) ]"
      }
    elseif ($TableName -like "*:*"){   # includes : (semicolon)
      $IssuesFound = $true
      Write-Output "  ISSUE - Table name include : (semicolon) - must be removed [ $($TableName) ]"
    }
    elseif ($TableName -like "*.*"){   # includes . (period)
      $IssuesFound = $true
      Write-Output "  ISSUE - Table name include . (period) - must be removed [ $($TableName) ]"
    }
    elseif ($TableName -like "* *"){   # includes whitespace " "
      $IssuesFound = $true
      Write-Output "  ISSUE - Table name include whitespace - must be removed [ $($TableName) ]"
    }

    if ($IssuesFound -eq $false){
        if (($AppId) -and ($AppSecret)){
            # Check if table and DCR exist - or schema must be updated due to source object schema changes             
            # Get insight about the schema structure
            $Schema = Get-LawObjectSchemaAsArray -Data $Data
            $StructureCheck = Get-LawTableDataCollectionRuleStatus `
            -LogWorkspaceResourceId $LogWorkspaceResourceId -TableName $TableName -DcrName $DcrName -SchemaSourceObject $Schema `
            -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

            # Structure check = $true -> Create/update table & DCR with necessary schema
            if ($StructureCheck -eq $true){
                if (($env:COMPUTERNAME -in $LogDcrTableCreateFromReferenceMachine) -or ($LogDcrTableCreateFromAnyMachine -eq $true)){    # manage table creations
                    # build schema to be used for LogAnalytics Table
                    $Schema = Get-LawObjectSchemaAsHash -Data $Data -ReturnType Table

                    $ResultLA = Set-LawCustomLogTableDcr -LogWorkspaceResourceId $LogWorkspaceResourceId -SchemaSourceObject $Schema -TableName $TableName `
                    -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId -SchemaMode $SchemaMode

                    # build schema to be used for DCR
                    $Schema = Get-LawObjectSchemaAsHash -Data $Data -ReturnType DCR

                    $ResultDCR = Set-LawCreateUpdateDataCollectionRuleLogIngestCustomLog -LogWorkspaceResourceId $LogWorkspaceResourceId -SchemaSourceObject $Schema `
                    -DcrName $DcrName -DcrResourceGroup $DcrResourceGroup -TableName $TableName -SchemaMode $SchemaMode `
                    -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

                    # Set permissions on DCR for Log Ingest App to ensure the Log Ingest App has permissions to upload data to the DCR
                    Set-LawDataCollectionRulePermissions -LogWorkspaceResourceId $LogWorkspaceResourceId -DcrName $DcrName -LogIngestServicePrincipalObjectId $LogIngestServicePrincipalObjectId `
                    -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId                 

                    Return $ResultLA, $ResultDCR
                }
            }
            elseif (($StructureCheck -eq $false) -and ($SetLogIngestApiAppPermissionsDcrLevel -eq $true)){
                # Set permissions on DCR for Log Ingest App - this is needed even if no schema changes are needed, to ensure the Log Ingest App has permissions to upload data to the DCR
                Set-LawDataCollectionRulePermissions -LogWorkspaceResourceId $LogWorkspaceResourceId -DcrName $DcrName -LogIngestServicePrincipalObjectId $LogIngestServicePrincipalObjectId `
                -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId
            }
            else {
                Write-Output "No issues found with table/DCR structure - No additional permissions needed - skipping create/update of table and DCR"
            }
        }
    }
}