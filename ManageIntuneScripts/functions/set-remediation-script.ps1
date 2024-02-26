function set-remediation-script {
    
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("create", "update", "remove")] 
        [string]$action,
        [Parameter(Mandatory=$true)]
        [ValidateSet("user", "system")] 
        [string]$runAsAccount,
        [Parameter(Mandatory=$true)]
        [ValidateSet("","true","false")] 
        [string]$runAs32Bit,
        [Parameter(Mandatory=$true)]
        [string]$vaultName,
        [Parameter(Mandatory=$true)]
        [string]$displayName,
        [Parameter(Mandatory=$true)]
        [string]$publisher,
        [Parameter(Mandatory=$false)]
        [string]$nDisplayName,
        [Parameter(Mandatory=$false)]
        [string]$description,
        [Parameter(Mandatory=$false)]
        [string]$detectPath,
        [Parameter(Mandatory=$false)]
        [string]$remediatePath,
        [Parameter(Mandatory=$false)]
        [array]$selectedAssignedGroups,
        [Parameter(Mandatory=$false)]
        [array]$selectedExcludedGroups,
        [Parameter(Mandatory=$false)]
        [array]$selectedScopeTags
    )

    begin {
        ################## Functions ##################

        function Get-Group(){
            [cmdletbinding()]
            param
            (
                [Parameter(Mandatory=$false)] $displayName,
                [Parameter(Mandatory=$false)] $id
            )
                # Defining Variables
                $graphApiVersion = "v1.0"
                $Resource = "groups"
                
                if($displayName){
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=displayName eq '$displayName'&`$count=true&ConsistencyLevel=eventual"
                }

                if($id){
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=id eq '$id'&`$count=true&ConsistencyLevel=eventual"
                }
    
                try {
                    (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
                }
                catch {   
                    $ex = $_.Exception
                    $errorResponse = $ex.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($errorResponse)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd();
    
                    Write-Output "Response content:`n$responseBody"
                    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                    break
                }     
        }
        
        function Get-ScopeTags(){

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/roleScopeTags" 
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }

        function Get-IntuneFilter(){

        [cmdletbinding()]
        
        param
        (
            $displayName
        )
            
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/assignmentFilters"
            
            try {
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).Value
            }
            catch {
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
        }

        function Get-deviceHealthScripts(){

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }
    
        function Get-deviceHealthScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceHealthScriptId
        )

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceHealthScriptId"

            try {
                Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }

        function Set-deviceHealthScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $json
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post -Body $json -ContentType "application/json")
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }
    
        function Update-deviceHealthScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceHealthScriptId,
            [Parameter(Mandatory=$true)] $json
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceHealthScriptId"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Patch -Body $json -ContentType "application/json")
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }
    
        function Remove-deviceHealthScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceHealthScriptId
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceHealthScriptId"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Delete)
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }
    
        function Get-deviceHealthScriptAssignment(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceHealthScriptId
        )

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceHealthScriptId/assignments"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Get).value
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }
    
        function Set-deviceHealthScriptAssignment(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceHealthScriptId,
            [Parameter(Mandatory=$true)] $json
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceHealthScriptId/assign"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post -Body $json -ContentType "application/json")
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }

        function Remove-deviceHealthScriptAssignment(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceHealthScriptAssignmentId
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceHealthScripts/assignments"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceHealthScriptAssignmentId"

            try {
                (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Delete)
            }
            catch {   
                $ex = $_.Exception
                $errorResponse = $ex.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();

                Write-Output "Response content:`n$responseBody"
                Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                break
            }     
        }

        # Configure modules needed to build msal token
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module MSAL.PS
        Import-Module MSAL.PS

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
    
            $token = Get-MsalToken @connectionDetails
            $authHeader = @{
                'Authorization' = $token.CreateAuthorizationHeader()
            }
            Write-Host "##[debug] msal token retrieved."
        } Catch {
            Write-Error $_.Exception.Message 
            write-host
            break
        }

        Write-Host "##[debug] action [$action] for remediation script [$displayName] initiated by [$publisher]."
        Write-Host "##[debug] description [$description]."
        Write-Host "##[debug] update displayName [$nDisplayName]."               
        Write-Host "##[debug] detect script [$detectPath]."
        Write-Host "##[debug] remediate script [$remediatePath]."
        Write-Host "##[debug] run as account [$runAsAccount]."
        Write-Host "##[debug] run as 32 bit [$runAs32Bit]."

        # The steps below can be skipped when action is remove detectPath and remediatePath can be empty
        if(($action -eq "create") -or ($action -eq "update")){
            if((-not(!$detectPath)) -or (-not(!$remediatePath))){
        
                if($detectPath){
                    $PSDefaultParameterValues = @{
                        "set-remediation-script:detectPath"=".\.ps1"
                    }
        
                    $detect_B64 = [convert]::ToBase64String((Get-Content $detectPath -Encoding byte))
                } 
                else {
                    Write-Host "##[debug] no detect script found."
                }
        
                if($remediatePath){
                    $PSDefaultParameterValues = @{
                        "set-remediation-script:detectPath"=".\.ps1"
                        "set-remediation-script:remediatePath"=".\.ps1"
                    }
        
                    $remediate_B64 = [convert]::ToBase64String((Get-Content $remediatePath -Encoding byte))
                } 
                else {
                    Write-Host "##[debug] no remediate script found."
                }
            }
            else {
                throw "detect and remediation script not found."
            }

            # Transform variable string input to an array with assigned- and excluded groups and scopetags
            if($selectedScopeTags){$scopeTags = $selectedScopeTags.Split(",")}
            if($selectedAssignedGroups){$assignedGroups = $selectedAssignedGroups.Split(",")}
            if($selectedExcludedGroups){$excludedGroups = $selectedExcludedGroups.Split(",")}

            # Check if given scope tags are found in Intune
            if(-not(!$scopeTags)){
                foreach ($scopeTag in $scopeTags){
                    $scopeTagId = (Get-ScopeTags | Where-Object {$_.displayName -eq $scopeTag}).id

                    if(-not(!$scopeTagId)){
                        [array]$scopeTagIds += $scopeTagId
                    }
                    else {
                        throw "scope tag [$scopeTag] not found."
                    }
                    Write-Host "##[debug] scope tag to assign [$scopeTag]."
                }
            }

            # Check if given assigned groups are found in Microsoft Entra Id
            if(-not(!$assignedGroups)){
                            
                $nAssignedGroups = @()
                foreach ($group in $assignedGroups){

                    $sg = $group.Split(";")

                    # Important to empty it
                    $groupId = @()
                    $groupId = $(Get-Group -displayName $sg[0]).id

                    $groupObject = [pscustomobject]@{
                        groupId=$groupId
                        displayName=$sg[0]
                        runSchedule=$sg[1]
                        interval=$sg[2]
                        time=$sg[3]
                        filterType=$sg[4]
                        filterName=$sg[5]
                        date=$sg[6]
                    }
                    $nAssignedGroups += $groupObject # Assigned groups output
                }
                    
                foreach ($nGroup in $nAssignedGroups){                    

                    if(-not(!$groupId)){

                        # check schedule here
                        if((-not(!$($nGroup.runSchedule))) -and (-not(!$($nGroup.interval)))){

                            $schedules = @('daily', 'hourly', 'once')  
                            if($schedules -notcontains $($nGroup.runSchedule)){
                                throw "runSchedule [$($nGroup.runSchedule)] not correct must be one of [$schedules]."
                            }
                        }
                        else {
                            throw "##vso[task.logissue type=error] runSchedule info not found."
                        }
                                
                        if((-not(!$($nGroup.filterType))) -and (-not(!$($nGroup.filterName)))){ 

                            $filterTypes = @('include', 'exclude')
                            if($filterTypes -notcontains $($nGroup.filterType)){ 
                                Write-Host "##vso[task.logissue type=error] runSchedule [$($nGroup.filterType)] not correct must be one of [$filterTypes]."
                            }

                            $filterId = (Get-IntuneFilter | Where-Object {$_.displayName -eq $($nGroup.filterName)}).id

                            if(!$filterId){
                                throw "##vso[task.logissue type=error] filterName [$($nGroup.filterName)] not found."
                            }
                        }
                        Write-Host "##[debug] group to assign [$($nGroup.displayName)] schedule [$($nGroup.runSchedule)] interval [$($nGroup.interval)] time [$($nGroup.time)] filterType [$($nGroup.filterType)] filterName [$($nGroup.filterName)]."
                    }
                    else {
                        throw "##vso[task.logissue type=error] assigned group [$($nGroup.displayName)] not found."
                    }
                }
            }

            # Check if given excluded groups are found in Microsoft Entra Id
            if(-not(!$excludedGroups)){
                foreach ($group in $excludedGroups){
                    $nExcludedGroup = Get-Group -displayName "$group"

                    if(-not(!$nExcludedGroup)){
                        [array]$nExcludedGroups += $nExcludedGroup
                    }
                    else {
                        throw "excluded group [$group] not found."
                    }
                    Write-Host "##[debug] group to exclude [$group]."
                }
            }
        }
    }

    process {
        ##################  Main logic ##################

        # Show all remediation scripts in Intune
        $remediationScripts = Get-deviceHealthScripts
        $remediationScripts.displayName

        # Get remediation script based on displayName
        $deviceHealthScript = ($remediationScripts | Where-Object {$_.displayName -eq $displayName})

        #################### Create remediation script block ####################
            
        if($action -eq "create"){

            # When deviceHealthScript is empty continue to create it
            if(!$deviceHealthScript){
                Write-Host "##[debug] start creating remediation script [$displayName]."

                # create remediation script (enforceSignatureCheck configured directly)
                $createRemediationJSON = @"
                {
                    "@odata.type": "#microsoft.graph.deviceHealthScript",
                    "publisher": "$publisher",
                    "displayName": "$displayName",
                    "description": "$description",
                    "detectionScriptContent": "$detect_B64",
                    "remediationScriptContent": "$remediate_B64",
                    "runAsAccount": "$runAsAccount",
                    "enforceSignatureCheck": "false",
                    "runAs32Bit": "$runAs32Bit",
                    "roleScopeTagIds": <roleScopeTagIds>
                }
"@
                $scopeTagIdsJSON = $scopeTagIds | ConvertTo-Json

                if(-not(!$scopeTagIds)){

                    if ($scopeTagIds.Count -eq 1){
                        $createRemediationJSON = $createRemediationJSON -replace '<roleScopeTagIds>',"[$scopeTagIdsJSON]"
                    }
                    else {
                        $createRemediationJSON = $createRemediationJSON -replace '<roleScopeTagIds>',$scopeTagIdsJSON
                    }
                }
                else {
                    $createRemediationJSON = $createRemediationJSON -replace '<roleScopeTagIds>',"[$scopeTagIdsJSON]"
                }

                # Create remediation script    
                $createdRemediationScript = Set-deviceHealthScript -json $createRemediationJSON
                Write-Host "##[debug] remediation script [$($createdRemediationScript.displayName)] with [$($createdRemediationScript.id)] created."
                
                # Start with logic for assign or exclude groups
                $groupsJSON = @"
                { 
                    "deviceHealthScriptAssignments":[
                    ]
                }
"@
                # Convert from JSON to PowerShell
                $g = $groupsJSON | ConvertFrom-Json
                
                # When assigned group(s) are found
                if(-not(!$nAssignedGroups)){
                    
                    foreach($ng in $nAssignedGroups){

                        # Build the JSON for adding info to the runSchedule
                        if($($ng.runSchedule) -eq "once"){
                            $nSchedule = @"
                            {
                                    "@odata.type":"#microsoft.graph.deviceHealthScriptRunOnceSchedule",
                                    "date":$($ng.date),
                                    "interval":$($ng.interval),
                                    "time":"$($ng.time)",
                                    "useUtc":false
                            }
"@       
                        }
                        if($($ng.runSchedule) -eq "daily"){
                            $nSchedule = @"
                            {
                                    "@odata.type":"#microsoft.graph.deviceHealthScriptDailySchedule",
                                    "interval":$($ng.interval),
                                    "time":"$($ng.time)",
                                    "useUtc":false
                            }
"@
                        }
                        if($($ng.runSchedule) -eq "hourly"){
                            $nSchedule = @"
                            {
                                    "@odata.type":"#microsoft.graph.deviceHealthScriptHourlySchedule",
                                    "interval":$($ng.interval)
                            }
"@                            
                        }

                        $groupAddJSON = @"
                        {
                            "target":{
                                "@odata.type":"#microsoft.graph.groupAssignmentTarget",
                                "groupId":"$($ng.groupId)"
                            },
                            "runRemediationScript":true,
                            "runSchedule":$nSchedule
                        }
"@
                        # Convert from JSON to PowerShell to add targets to deviceHealthScriptAssignments
                        $ga = $groupAddJSON | ConvertFrom-Json

                        if((-not(!$($ng.filterType))) -and (-not(!$($ng.filterName)))){ 

                            $filterId = (Get-IntuneFilter | Where-Object {$_.displayName -eq $($ng.filterName)}).id

                            $ga.target | Add-Member -MemberType NoteProperty -Name "deviceAndAppManagementAssignmentFilterId" -Value "$filterId"
                            $ga.target | Add-Member -MemberType NoteProperty -Name "deviceAndAppManagementAssignmentFilterType" -Value "$($ng.filterType)"
                        }

                        $g.deviceHealthScriptAssignments += $ga
                        Write-Host "##[debug] group [$($nGroup.displayName)] schedule [$($ng.runSchedule)] interval [$($ng.interval)] time [$($ng.time)] filterType [$($ng.filterType)] filterName [$($ng.filterName)] added as assigned group to [$($createdRemediationScript.displayName)]."
                    }
                }

                # When excluded group(s) are found
                if (-not(!$nExcludedGroups)){

                    foreach($nGroup in $nExcludedGroups){

                        $groupExcludeJSON = @"
                        {
                            "target":{
                                "@odata.type":"#microsoft.graph.exclusionGroupAssignmentTarget",
                                "groupId":"$($nGroup.id)"
                            },
                            "runRemediationScript":true
                        }
"@
                        $ge = $groupExcludeJSON | ConvertFrom-Json
                        $g.deviceHealthScriptAssignments += $ge
                        Write-Host "##[debug] group [$($nGroup.displayName)] added as excluded group to [$($createdRemediationScript.displayName)]."
                    }
                }
                
                # Create group assignments
                if((-not(!$groupAddJSON)) -or (-not(!$groupExcludeJSON))){
                    $groupsJSON = $g | ConvertTo-Json -depth 32
                    Set-deviceHealthScriptAssignment -deviceHealthScriptId $($createdRemediationScript.id) -json $groupsJSON
                }
                else {
                    Set-deviceHealthScriptAssignment -deviceHealthScriptId $($createdRemediationScript.id) -json $groupsJSON
                }
            }
            else {
                throw "remediation script with displayName [$displayName] already exist."
            }            
        }

        #################### Update remediation script block ####################

        if($action -eq "update"){

            # When deviceHealthScript is found continue to update it
            if(-not(!$deviceHealthScript)){
                Write-Host "##[debug] start updating remediation script [$displayName]."

                $changedSettings = 0
                $cRemediation = Get-deviceHealthScript -deviceHealthScriptId $($deviceHealthScript.id)

                ########## Update remediation script settings ##########
                $updateRemediationJSON = @"
                {
                    "@odata.type": "#microsoft.graph.deviceHealthScript",
                    "publisher": "$publisher",
                    "displayName": "<displayName>",
                    "description": "<description>",
                    "detectionScriptContent": "<detectionScriptContent>",
                    "remediationScriptContent": "<remediationScriptContent>",
                    "runAsAccount": "<runAsAccount>",
                    "runAs32Bit": "<runAs32Bit>",
                    "enforceSignatureCheck": "false",
                    "roleScopeTagIds": <roleScopeTagIds>
                }
"@
                # Update displayName
                if(-not(!$nDisplayName)){
                    if ($nDisplayName -ne ($cRemediation.displayName)){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<displayName>',$nDisplayName
                        $changedSettings += 1
                        Write-Host "##[debug] displayName updated from [$($cRemediation.displayName)] to [$nDisplayName]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<displayName>',$($cRemediation.displayName)
                        Write-Host "##[debug] displayName already [$($cRemediation.displayName)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<displayName>',$($cRemediation.displayName)
                }

                # Update description
                if(-not(!$description)){
                    if ($description -ne ($cRemediation.description)){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<description>',$description
                        $changedSettings += 1
                        Write-Host "##[debug] description updated from [$($cRemediation.description)] to [$description]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<description>',$($cRemediation.description)
                        Write-Host "##[debug] description already [$($cRemediation.description)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<description>',$($cRemediation.description)
                }

                # Update detectionScriptContent
                if(-not(!$detect_B64)){
                    if ($detect_B64 -ne ($cRemediation.detectionScriptContent)){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<detectionScriptContent>',$detect_B64
                        $changedSettings += 1
                        Write-Host "##[debug] detection script updated from [$($cRemediation.detectionScriptContent)] to [$detect_B64]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<detectionScriptContent>',$($cRemediation.detectionScriptContent)
                        Write-Host "##[debug] detection script already [$($cRemediation.detectionScriptContent)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<detectionScriptContent>',$($cRemediation.detectionScriptContent)
                }

                # Update remediationScriptContent
                if(-not(!$remediate_B64)){
                    if ($remediate_B64 -ne ($cRemediation.remediationScriptContent)){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<remediationScriptContent>',$remediate_B64
                        $changedSettings += 1
                        Write-Host "##[debug] remediation script updated from [$($cRemediation.remediationScriptContent)] to [$remediate_B64]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<remediationScriptContent>',$($cRemediation.remediationScriptContent)
                        Write-Host "##[debug] remediation script already [$($cRemediation.remediationScriptContent)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<remediationScriptContent>',$($cRemediation.remediationScriptContent)
                }

                # Update runAsAccount
                if(-not(!$runAsAccount)){
                    if ($runAsAccount -ne ($cRemediation.runAsAccount)){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<runAsAccount>',$runAsAccount
                        $changedSettings += 1
                        Write-Host "##[debug] runAsAccount updated from [$($cRemediation.runAsAccount)] to [$runAsAccount]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<runAsAccount>',$($cRemediation.runAsAccount)
                        Write-Host "##[debug] runAsAccount already [$($cRemediation.runAsAccount)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<runAsAccount>',$($cRemediation.runAsAccount)
                }

                # Update runAs32Bit
                if(-not(!$runAs32Bit)){
                    if ($runAs32Bit -ne ($cRemediation.runAs32Bit)){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<runAs32Bit>',$runAs32Bit
                        $changedSettings += 1
                        Write-Host "##[debug] runAs32Bit updated from [$($cRemediation.runAs32Bit)] to [$runAs32Bit]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<runAs32Bit>',$($cRemediation.runAs32Bit)
                        Write-Host "##[debug] runAs32Bit already [$($cRemediation.runAs32Bit)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<runAs32Bit>',$($cRemediation.runAs32Bit)
                }

                ########## Update scope tags ##########

                # Get current scope tags on remediation script            
                foreach ($scopeTagId in $($cRemediation.roleScopeTagIds)){
                    [array]$cScopeTagIds += $scopeTagId
                }

                # Get device scope tags to verify if tag id needs to be added or removed
                if((-not(!$scopeTagIds)) -or ($cScopeTagIds -ne 0)){
                                    
                    # Get remediation scope tags to verify if tag id needs to be added
                    $scopeTagIds | ForEach-Object{
                        if($cScopeTagIds -notcontains $_){
                            [array]$updatedScopeTagIds += $_
                            $changedSettings += 1
                            Write-Host "##[debug] scope tag id [$_] added to [$($cRemediation.displayName)]."
                        }
                        else {
                            [array]$updatedScopeTagIds += $_
                            Write-Host "##[debug] scope tag id [$_] already assigned to [$($cRemediation.displayName)]."
                        }
                    }

                    $cScopeTagIds | ForEach-Object{
                        if($scopeTagIds -notcontains $_){
                            $changedSettings += 1
                            Write-Host "##[debug] scope tag id [$_] removed from [$($cRemediation.displayName)]."
                        }
                    }

                    $scopeTagIdsJSON = $updatedScopeTagIds | ConvertTo-Json

                    if ($updatedScopeTagIds.Count -le 1){
                        $updateRemediationJSON = $updateRemediationJSON -replace '<roleScopeTagIds>',"[$scopeTagIdsJSON]"
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<roleScopeTagIds>',$scopeTagIdsJSON
                    }
                }
                else {
                    # No scope tags found
                    $updateRemediationJSON = $updateRemediationJSON -replace '<roleScopeTagIds>',"[]"
                    $changedSettings += 1
                    Write-Host "##[debug] no scope tag id found assign default to [$($cRemediation.displayName)]."
                }

                # Update all settings on remediation script
                if ($changedSettings -ne 0){
                    Update-deviceHealthScript -deviceHealthScriptId $($deviceHealthScript.id) -json $updateRemediationJSON
                    Write-Host "##[debug] updated [$changedSettings] settings on remediation script [$($deviceHealthScript.displayName)]."
                }  
            
                ########## Update groupmemberships ##########

                # Get microsoft.graph.groupAssignmentTarget groups on remediation script
                $cGroupAssignments = (Get-deviceHealthScriptAssignment -deviceHealthScriptId $($deviceHealthScript.id) | `
                Where-Object {$_.target."@odata.type" -eq "#microsoft.graph.groupAssignmentTarget"})

                # Get microsoft.graph.exclusionGroupAssignmentTarget groups on remediation script
                $cExclusionGroupAssignments = (Get-deviceHealthScriptAssignment -deviceHealthScriptId $($deviceHealthScript.id) | `
                Where-Object {$_.target."@odata.type" -eq "#microsoft.graph.exclusionGroupAssignmentTarget"})

                # Start with logic for microsoft.graph.groupAssignmentTarget and microsoft.graph.exclusionGroupAssignmentTarget
                $groupsJSON = @"
                { 
                    "deviceHealthScriptAssignments":[
                    ]
                }
"@
                # Convert from JSON to PowerShell to have a template that can be filled
                $g = $groupsJSON | ConvertFrom-Json

                # When new assigned group(s) are found
                if(-not(!$nAssignedGroups)){
                                
                    $nAssignedGroups | ForEach-Object{

                        if($($_.runSchedule) -eq "once"){
                            $nSchedule = @"
                            {
                                    "@odata.type":"#microsoft.graph.deviceHealthScriptRunOnceSchedule",
                                    "date":$($_.date),
                                    "interval":$($_.interval),
                                    "time":"$($_.time)",
                                    "useUtc":false
                            }
"@       
                        }
                        if($($_.runSchedule) -eq "daily"){
                            $nSchedule = @"
                            {
                                    "@odata.type":"#microsoft.graph.deviceHealthScriptDailySchedule",
                                    "interval":$($_.interval),
                                    "time":"$($_.time)",
                                    "useUtc":false
                            }
"@
                        }
                        if($($_.runSchedule) -eq "hourly"){
                            $nSchedule = @"
                            {
                                    "@odata.type":"#microsoft.graph.deviceHealthScriptHourlySchedule",
                                    "interval":$($_.interval)
                            }
"@                            
                        }

                        $groupAddJSON = @"
                        {
                            "target":{
                                "@odata.type":"#microsoft.graph.groupAssignmentTarget",
                                "groupId":"$($_.groupId)"
                            },
                            "runRemediationScript":true,
                            "runSchedule":$nSchedule
                        }
"@

                        # Convert from JSON to PowerShell to add targets to deviceHealthScriptAssignments
                        $ga = $groupAddJSON | ConvertFrom-Json

                        if((-not(!$($_.filterType))) -and (-not(!$($_.filterName)))){

                            $filterName = $($_.filterName)
                            $filterId = (Get-IntuneFilter | Where-Object {$_.displayName -eq $filterName}).id
                                            
                            $ga.target | Add-Member -MemberType NoteProperty -Name "deviceAndAppManagementAssignmentFilterId" -Value "$filterId"
                            $ga.target | Add-Member -MemberType NoteProperty -Name "deviceAndAppManagementAssignmentFilterType" -Value "$($_.filterType)"
                        }

                        if($($cGroupAssignments.target.groupId) -notcontains $($_.groupId)){                               
                            $g.deviceHealthScriptAssignments += $ga
                            Write-Host "##[debug] group [$($_.displayName)] added with schedule [$($_.runSchedule)] interval [$($_.interval)] time [$($_.time)] filterType [$($_.filterType)] filterName [$($_.filterName)] to [$($deviceHealthScript.displayName)]."
                        }
                        else {        
                            $g.deviceHealthScriptAssignments += $ga
                            Write-Host "##[debug] group [$($_.displayName)] already assigned with updated schedule [$($_.runSchedule)] interval [$($_.interval)] time [$($_.time)] filterType [$($_.filterType)] filterName [$($_.filterName)] to [$($deviceHealthScript.displayName)]."
                        }
                    }
                }

                # When current assigned group(s) are found
                if(-not(!$cGroupAssignments)){

                    # Check microsoft.graph.groupAssignmentTarget current groups
                    $cGroupAssignments | ForEach-Object{
                        $group = Get-Group -id $($_.target.groupId)

                        if($($nAssignedGroups.groupId) -notcontains $($_.target.groupId)){
                            Write-Host "##[debug] group [$($group.displayName)] removed as assigned group from [$($deviceHealthScript.displayName)]."
                        }
                    }
                }

                # When new excluded group(s) are found
                if(-not(!$nExcludedGroups)){

                    # Add deviceHealthScriptExclusionAssignments
                    $nExcludedGroups | ForEach-Object{
                        if($($cExclusionGroupAssignments.target.groupId) -notcontains $($_.id)){

                            $groupExcludeJSON = @"
                            {
                                "target":{
                                    "@odata.type":"#microsoft.graph.exclusionGroupAssignmentTarget",
                                    "groupId":"$($_.id)"
                                },
                                "runRemediationScript":true
                            }
"@
                            # Convert from JSON to PowerShell to add targets to deviceHealthScriptExclusionAssignments
                            $ge = $groupExcludeJSON | ConvertFrom-Json
                            $g.deviceHealthScriptAssignments += $ge

                            Write-Host "##[debug] group [$($_.displayName)] added as excluded group to [$($deviceHealthScript.displayName)]."
                        }
                    }
                }

                if(-not(!$cExclusionGroupAssignments)){

                    # Remove deviceHealthScriptExclusionAssignments
                    $cExclusionGroupAssignments | ForEach-Object{
                        $group = Get-Group -id $($_.target.groupId)

                        if($($nExcludedGroups.id) -contains $($_.target.groupId)){

                            $groupExcludeJSON = @"
                            {
                                "target":{
                                    "@odata.type":"#microsoft.graph.exclusionGroupAssignmentTarget",
                                    "groupId":"$($_.target.groupId)"
                                },
                                "runRemediationScript":true
                            }
"@
                            # Convert from JSON to PowerShell to add targets to deviceHealthScriptExclusionAssignments that are already assigned
                            $ge = $groupExcludeJSON | ConvertFrom-Json
                            $g.deviceHealthScriptAssignments += $ge

                            Write-Host "##[debug] group [$($group.displayName)] already an excluded group on [$($deviceHealthScript.displayName)]."
                        }
                        else {
                            Write-Host "##[debug] group [$($group.displayName)] removed as excluded group from [$($deviceHealthScript.displayName)]."
                        }
                    }
                }
                            
                # Update groupassignments
                if((-not(!$groupAddJSON)) -or (-not(!$groupExcludeJSON))){
                    $groupsJSON = $g | ConvertTo-Json -depth 32
                    Set-deviceHealthScriptAssignment -deviceHealthScriptId $($deviceHealthScript.id) -json $groupsJSON
                }
                else {
                    Set-deviceHealthScriptAssignment -deviceHealthScriptId $($deviceHealthScript.id) -json $groupsJSON
                }
            }
            else {
                throw "remediation script with displayName [$displayName] does not exist."        
            }
        }

        #################### Remove remediation script block ####################

        if($action -eq "remove"){

            # When deviceHealthScript is found continue to remove it
            if(-not(!$deviceHealthScript)){
                Write-Host "##[debug] start removing remediation script [$displayName]."

                # Remove remediation script
                Remove-deviceHealthScript -deviceHealthScriptId $($deviceHealthScript.id)
                Write-Host "##[debug] remediation script [$displayName] removed."
            }
            else {
                throw "remediation script with displayName [$displayName] does not exist."
            }
        }
    }
}