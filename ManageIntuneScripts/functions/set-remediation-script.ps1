#=============================================================================================================================
# Script Name:     set-remediation-script.ps1
# Description:     Run this function to create, update or remove Intune remediation scripts. 
#   
# Notes      :     It's necessary to use the vars.txt with the following info:
#                  displayName=Testnew
#                  nDisplayName=
#                  description=Testnew
#                  detectScript=VirtualizationBasedProtection_Detect.ps1
#                  remediateScript=VirtualizationBasedProtection_Remediate.ps1
#                  runAsAccount=system
#                  runAs32Bit=false
#                  assignedGroups=SG-CL-TESTGROUP;once;1;1:0:0;2024-02-29,SG-CL-CMW-L-A-NL-00;hourly;1;include;W11
#                  ,SG-CL-CMW-L-P-NL-00;daily;1;1:0:0;include;W10
#                  excludedGroups=
#                  scopeTags=WPS-CDS-NL-01,WPS-CDS-NL-00
#
# Created by :     Ivo Uenk
# Date       :     15-09-2025
# Version    :     1.3
#=============================================================================================================================

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
        [Parameter(Mandatory=$true)]
        [string]$environment,
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
        $secureClientId = (Get-AzKeyVaultSecret -VaultName $VaultName -Name RWAppId).SecretValue
        $secureSecret = (Get-AzKeyVaultSecret -VaultName $VaultName -Name RWSecret).SecretValue
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

        Write-Host "##[debug] action [$action] for remediation script [$displayName] initiated by [$publisher] on environment [$environment]."
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
                    Write-Host "##[debug] [$displayName] no detect script found."
                }
        
                if($remediatePath){
                    $PSDefaultParameterValues = @{
                        "set-remediation-script:detectPath"=".\.ps1"
                        "set-remediation-script:remediatePath"=".\.ps1"
                    }
        
                    $remediate_B64 = [convert]::ToBase64String((Get-Content $remediatePath -Encoding byte))
                } 
                else {
                    Write-Host "##[debug] [$displayName] no remediate script found."
                }
            }
            else {
                throw "[$displayName] detect and remediation script not found."
            }

            # Check if given scope tags are found in Intune
            if ($selectedScopeTags){$scopeTags = $selectedScopeTags.Split(",")}

            if (-not(!$scopeTags)){
                foreach ($scopeTag in $scopeTags){
                    $tagToAssign = Get-ScopeTags | Where-Object {$_.displayName -eq $scopeTag}

                    if(-not(!$tagToAssign)){
                        Write-Host "##[debug] [$displayName] scope tag to assign [$($tagToAssign.displayName)]."
                        [array]$tagsToAssign += $tagToAssign
                    }
                    else {
                        throw "[$displayName] scope tag [$scopeTag] not found."
                    }
                }
            }

            # Check if given assigned groups are found in Microsoft Entra Id
            if ($selectedAssignedGroups){$assignedGroups = $selectedAssignedGroups.Split(",")}

            if (-not(!$assignedGroups)){
                            
                $nAssignedGroups = @()
                foreach ($group in $assignedGroups){
                    
                    ### IMPORTANT FOLLOW THE CORRECT ORDER OF PARAMETERS IN VARS.TXT ###
                    $sg = @()
                    $sg = $group.Split(";")
                
                    # Important to empty it
                    $groupId = @()
                    $groupId = $(Get-Group -displayName $sg[0]).id
                
                    # Parameters that can be different
                    $time = $null
                    $date = $null
                    $filterType = $null
                    $filterName = $null
                
                    if($sg[3] -like "*:0:0"){
                        $time = $sg[3]
                    } elseif(($sg[3] -eq "include") -or ($sg[3] -eq "exclude")){
                        $time = $null
                        $filterType = $sg[3]
                    } else {
                        $time = $null
                        $filterType = $null
                    }
                
                    if ($sg[4] -match "\d+"){
                        $date = $sg[4]
                    } elseif (($sg[4] -eq "include") -or ($sg[4] -eq "exclude")){
                        $date = $null
                        $filterType = $sg[4]   
                    } else {
                        $filterName = $sg[4]   
                    }
                
                    if($null -ne $sg[5]){$filterName = $sg[5]}
                
                    $groupObject = [pscustomobject]@{
                        groupId=$groupId
                        displayName=$sg[0]
                        runSchedule=$sg[1]
                        interval=$sg[2]
                        time=$time
                        date=$date
                        filterType=$filterType
                        filterName=$filterName
                    }
                    $nAssignedGroups += $groupObject # Assigned groups output
                }
                    
                foreach ($nGroup in $nAssignedGroups){                    

                    if($null -ne $($nGroup.groupId)){

                        # check schedule here
                        if((-not(!$($nGroup.runSchedule))) -and (-not(!$($nGroup.interval)))){

                            $schedules = @('daily', 'hourly', 'once')  
                            if($schedules -notcontains $($nGroup.runSchedule)){
                                throw "[$displayName] runSchedule [$($nGroup.runSchedule)] not correct must be one of [$schedules]."
                            }
                        }
                        else {
                            throw "[$displayName] runSchedule info not found."
                        }
                                
                        if((-not(!$($nGroup.filterType))) -and (-not(!$($nGroup.filterName)))){ 

                            $filterTypes = @('include', 'exclude')
                            if($filterTypes -notcontains $($nGroup.filterType)){ 
                                throw "[$displayName] runSchedule [$($nGroup.filterType)] not correct must be one of [$filterTypes]."
                            }

                            $filterId = (Get-IntuneFilter | Where-Object {$_.displayName -eq $($nGroup.filterName)}).id

                            if(!$filterId){
                                throw "[$displayName] filterName [$($nGroup.filterName)] not found."
                            }
                        }
                        Write-Host "##[debug] [$displayName] group to assign [$($nGroup.displayName)] schedule [$($nGroup.runSchedule)] interval [$($nGroup.interval)] time [$($nGroup.time)] date [$($nGroup.date)] filterType [$($nGroup.filterType)] filterName [$($nGroup.filterName)]."
                    }
                    else {
                        throw "[$displayName] assigned group [$($nGroup.displayName)] not found."
                    }
                }
            }

            # Check if given excluded groups are found in Microsoft Entra Id
            if ($selectedExcludedGroups){$excludedGroups = $selectedExcludedGroups.Split(",")}

            if (-not(!$excludedGroups)){
                foreach ($group in $excludedGroups){
                    $nExcludedGroup = Get-Group -displayName "$group"

                    if(-not(!$nExcludedGroup)){
                        [array]$nExcludedGroups += $nExcludedGroup
                    }
                    else {
                        throw "[$displayName] excluded group [$group] not found."
                    }
                    Write-Host "##[debug] [$displayName] group to exclude [$group]."
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
                $scopeTagIdsJSON = $($tagsToAssign.id) | ConvertTo-Json

                if (-not(!$($tagsToAssign.id))){

                    if ($($tagsToAssign.id).Count -eq 1){
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
                Write-Host "##[debug] [$displayName] remediation script [$($createdRemediationScript.displayName)] with [$($createdRemediationScript.id)] created."
                
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
                                    "date":"$($ng.date)",
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
                        Write-Host "##[debug] [$displayName] group [$($nGroup.displayName)] schedule [$($ng.runSchedule)] interval [$($ng.interval)] time [$($ng.time)] date [$($ng.date)] filterType [$($ng.filterType)] filterName [$($ng.filterName)] added as assigned group."
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
                        Write-Host "##[debug] [$displayName] group [$($nGroup.displayName)] added as excluded group."
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
                throw "[$displayName] remediation script already exist."
            }            
        }

        #################### Update remediation script block ####################

        if($action -eq "update"){

            # When deviceHealthScript is found continue to update it
            if(-not(!$deviceHealthScript)){
                Write-Host "##[debug] [$displayName] start updating remediation script."

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
                        Write-Host "##[debug] [$displayName] displayName updated from [$($cRemediation.displayName)] to [$nDisplayName]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<displayName>',$($cRemediation.displayName)
                        Write-Host "##[debug] [$displayName] displayName already [$($cRemediation.displayName)]."
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
                        Write-Host "##[debug] [$displayName] description updated from [$($cRemediation.description)] to [$description]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<description>',$($cRemediation.description)
                        Write-Host "##[debug] [$displayName] description already [$($cRemediation.description)]."
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
                        Write-Host "##[debug] [$displayName] detection script updated from [$($cRemediation.detectionScriptContent)] to [$detect_B64]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<detectionScriptContent>',$($cRemediation.detectionScriptContent)
                        Write-Host "##[debug] [$displayName] detection script already [$($cRemediation.detectionScriptContent)]."
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
                        Write-Host "##[debug] [$displayName] remediation script updated from [$($cRemediation.remediationScriptContent)] to [$remediate_B64]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<remediationScriptContent>',$($cRemediation.remediationScriptContent)
                        Write-Host "##[debug] [$displayName] remediation script already [$($cRemediation.remediationScriptContent)]."
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
                        Write-Host "##[debug] [$displayName] runAsAccount updated from [$($cRemediation.runAsAccount)] to [$runAsAccount]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<runAsAccount>',$($cRemediation.runAsAccount)
                        Write-Host "##[debug] [$displayName] runAsAccount already [$($cRemediation.runAsAccount)]."
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
                        Write-Host "##[debug] [$displayName] runAs32Bit updated from [$($cRemediation.runAs32Bit)] to [$runAs32Bit]."
                    }
                    else {
                        $updateRemediationJSON = $updateRemediationJSON -replace '<runAs32Bit>',$($cRemediation.runAs32Bit)
                        Write-Host "##[debug] [$displayName] runAs32Bit already [$($cRemediation.runAs32Bit)]."
                    }
                } 
                else {
                    $updateRemediationJSON = $updateRemediationJSON -replace '<runAs32Bit>',$($cRemediation.runAs32Bit)
                }

                ########## Update scope tags ##########

                # Get current scope tags on remediation script            
                foreach ($scopeTagId in $($cRemediation.roleScopeTagIds)){
                    $scopeTag = (Get-ScopeTags | Where-Object {$_.id -eq $scopeTagId})
                    [array]$cScopeTags += $scopeTag
                }

                # Get device scope tags to verify if tag id needs to be added or removed
                if ((-not(!$($tagsToAssign.id))) -or ($($cScopeTagIds.id) -ne 0)){
                                    
                    # Get remediation scope tags to verify if tag id needs to be added
                    $tagsToAssign | ForEach-Object {
                        if ($($cScopeTags.id) -notcontains $($_.id)){
                            [array]$updatedScopeTagIds += $($_.id)
                            $changedSettings += 1
                            Write-Host "##[debug] [$displayName] scope tag [$($_.displayName)] with id [$($_.id)] added."
                        }
                        else {
                            [array]$updatedScopeTagIds += $($_.id)
                            Write-Host "##[debug] [$displayName] scope tag [$($_.displayName)] with id [$($_.id)] already assigned."
                        }
                    }

                    $cScopeTags | ForEach-Object{
                        if($($tagsToAssign.id) -notcontains $($_.id)){
                            $changedSettings += 1
                            Write-Host "##[debug] [$displayName] scope tag [$($_.displayName)] with id [$($_.id)] removed."
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
                    Write-Host "##[debug] [$displayName] no scope tag id found assign default."
                }

                # Update all settings on remediation script
                if ($changedSettings -ne 0){
                    Update-deviceHealthScript -deviceHealthScriptId $($deviceHealthScript.id) -json $updateRemediationJSON
                    Write-Host "##[debug] [$displayName] updated [$changedSettings] settings on remediation script."
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
                                    "date":"$($_.date)",
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
                            Write-Host "##[debug] [$displayName] group [$($_.displayName)] added with schedule [$($_.runSchedule)] interval [$($_.interval)] time [$($_.time)] date [$($_.date)] filterType [$($_.filterType)] filterName [$($_.filterName)]."
                        }
                        else {        
                            $g.deviceHealthScriptAssignments += $ga
                            Write-Host "##[debug] [$displayName] group [$($_.displayName)] already assigned with updated schedule [$($_.runSchedule)] interval [$($_.interval)] time [$($_.time)] date [$($_.date)] filterType [$($_.filterType)] filterName [$($_.filterName)]."
                        }
                    }
                }

                # When current assigned group(s) are found
                if(-not(!$cGroupAssignments)){

                    # Check microsoft.graph.groupAssignmentTarget current groups
                    $cGroupAssignments | ForEach-Object{
                        $group = Get-Group -id $($_.target.groupId)

                        if($($nAssignedGroups.groupId) -notcontains $($_.target.groupId)){
                            Write-Host "##[debug] [$displayName] group [$($group.displayName)] removed as assigned group."
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

                            Write-Host "##[debug] [$displayName] group [$($_.displayName)] added as excluded group."
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

                            Write-Host "##[debug] [$displayName] group [$($group.displayName)] already an excluded group."
                        }
                        else {
                            Write-Host "##[debug] [$displayName] group [$($group.displayName)] removed as excluded group."
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
                throw "[$displayName] remediation script does not exist."        
            }
        }

        #################### Remove remediation script block ####################

        if($action -eq "remove"){

            # When deviceHealthScript is found continue to remove it
            if(-not(!$deviceHealthScript)){
                Write-Host "##[debug] [$displayName] start removing remediation script."

                # Remove remediation script
                Remove-deviceHealthScript -deviceHealthScriptId $($deviceHealthScript.id)
                Write-Host "##[debug] [$displayName] remediation script removed."
            }
            else {
                throw "[$displayName] remediation script does not exist."
            }
        }
    }
}