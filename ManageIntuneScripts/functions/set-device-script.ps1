function set-device-script {

    <#
    .DESCRIPTION
    Run this function to create, update or remove Intune device scripts. This function script is addressed in pipe set-device-script.yml.
    Initial Author: Ivo Uenk (udirection.com).
    The script is provided "AS IS" with no warranties.
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("create", "update", "remove")] 
        [string]$action,
        [Parameter(Mandatory=$true)]
        [ValidateSet("","user", "system")] 
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
        [string]$cDisplayName,
        [Parameter(Mandatory=$false)]
        [string]$description,
        [Parameter(Mandatory=$true)]
        [string]$fileName,
        [Parameter(Mandatory=$false)]
        [string]$scriptPath, 
        [Parameter(Mandatory=$false)]
        [array]$selectedIncludedGroups,
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
    
        function Get-deviceManagementScripts(){

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts"  
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
    
        function Get-deviceManagementScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceManagementScriptId
        )

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceManagementScriptId"

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

        function Set-deviceManagementScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $json
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts"  
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

        function Update-deviceManagementScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceManagementScriptId,
            [Parameter(Mandatory=$true)] $json
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts" 
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceManagementScriptId"

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

        function Remove-deviceManagementScript(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceManagementScriptId
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceManagementScriptId"

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

        function Get-deviceManagementScriptAssignment(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceManagementScriptId
        )

            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceManagementScriptId/assignments"

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

        function Set-deviceManagementScriptAssignment(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceManagementScriptId,
            [Parameter(Mandatory=$true)] $json
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagementScripts"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceManagementScriptId/assign"

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

        function Remove-deviceManagementScriptAssignment(){
        [cmdletbinding()]
        param
        (
            [Parameter(Mandatory=$true)] $deviceManagementScriptAssignmentId
        )
            # Defining Variables
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/deviceManagement/deviceManagementScripts/assignments"  
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$deviceManagementScriptAssignmentId"

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

        Write-Host "##[debug] action [$action] for device script [$displayName] initiated by [$publisher]."
        Write-Host "##[debug] description [$description]."
        Write-Host "##[debug] update displayName [$nDisplayName]."               
        Write-Host "##[debug] device script [$scriptPath]."
        Write-Host "##[debug] run as account [$runAsAccount]."

        # The steps below can be skipped when action is remove scriptPath can be empty
        if(($action -eq "create") -or ($action -eq "update")){
            if(-not(!$scriptPath)){
                $PSDefaultParameterValues = @{
                    "set-device-script:scriptPath"=".\.ps1"
                }

                $scriptPath_B64 = [convert]::ToBase64String((Get-Content $scriptPath -Encoding byte))
            }
            else {
                throw "##vso[task.logissue type=error] device script not found."
            }

            # Transform variable string input to an array with include groups and scopetags
            if($selectedScopeTags){$scopeTags = $selectedScopeTags.Split(",")}
            if($selectedIncludedGroups){$includedGroups = $selectedIncludedGroups.Split(",")}

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

            # Check if given include groups are found in Microsoft Entra ID
            if(-not(!$includedGroups)){
                foreach ($group in $includedGroups){
                    $nIncludedGroup = Get-Group -displayName "$group"

                    if(-not(!$nIncludedGroup)){
                        [array]$nIncludedGroups += $nIncludedGroup
                    }
                    else {
                        throw "include group [$group] not found."
                    }
                    Write-Host "##[debug] group to include [$group]."
                }
            }
        }
    }

    process {
        ##################  Main logic ##################

        # Show all device scripts in Intune
        $deviceScripts = Get-deviceManagementScripts
        $deviceScripts.displayName

        # Get device script based on displayName
        $deviceScript = ($deviceScripts | Where-Object {$_.displayName -eq $displayName})

        #################### Create device script block ####################

        if($action -eq "create"){
            
            # When deviceManagementScript is empty continue to create it
            if(!$deviceScript){
                Write-Host "##[debug] start creating device script [$displayName]."

                # create device script (enforceSignatureCheck configured directly)
                $createScriptJSON = @"
                {
                    "@odata.type": "#microsoft.graph.deviceManagementScript",
                    "displayName": "$displayName",
                    "description": "$description",
                    "scriptContent": "$scriptPath_B64",
                    "fileName": "$fileName",
                    "runAsAccount": "$runAsAccount",
                    "runAs32Bit": "$runAs32Bit",
                    "enforceSignatureCheck": false,
                    "roleScopeTagIds": <roleScopeTagIds>
                }
"@
                $scopeTagIdsJSON = $scopeTagIds | ConvertTo-Json

                if(-not(!$scopeTagIds)){

                    if ($scopeTagIds.Count -eq 1){
                        $createScriptJSON = $createScriptJSON -replace '<roleScopeTagIds>',"[$scopeTagIdsJSON]"
                    }
                    else {
                        $createScriptJSON = $createScriptJSON -replace '<roleScopeTagIds>',$scopeTagIdsJSON
                    }
                }
                else {
                    $createScriptJSON = $createScriptJSON -replace '<roleScopeTagIds>',"[$scopeTagIdsJSON]"
                }

                # Create device script    
                $createdDeviceScript = Set-deviceManagementScript -json $createScriptJSON
                Write-Host "##[debug] device script [$($createdDeviceScript.displayName)] with [$($createdDeviceScript.id)] created."
                    
                # Start with logic for include groups
                $groupsJSON = @"
                { 
                    "deviceManagementScriptAssignments":[
                    ]
                }
"@
                # Convert from JSON to PowerShell
                $g = $groupsJSON | ConvertFrom-Json
                
                # When included group(s) are found
                if(-not(!$nIncludedGroups)){

                    foreach($nGroup in $nIncludedGroups){

                        $groupAddJSON = @"
                        {
                            "target":{
                                "@odata.type":"#microsoft.graph.groupAssignmentTarget",
                                "groupId":"$($nGroup.id)"
                            }
                        }
"@
                        # Convert from JSON to PowerShell to add targets to deviceManagementScriptAssignments
                        $ga = $groupAddJSON | ConvertFrom-Json
                        $g.deviceManagementScriptAssignments += $ga

                        Write-Host "##[debug] group [$($nGroup.displayName)] added as included group to [$($createdDeviceScript.displayName)]."
                    }
                    $groupsJSON = $g | ConvertTo-Json -depth 32
                }

                # Create group assignments
                Set-deviceManagementScriptAssignment -deviceManagementScriptId $($createdDeviceScript.id) -json $groupsJSON
            }
            else {
                throw "device script with displayName [$displayName] already exist."
            }
        }

        #################### Update device script block ####################

        # When deviceManagementScript is not empty continue
        if($action -eq "update"){

            # When deviceManagementScript is found continue to update it
            if(-not(!$deviceScript)){
                Write-Host "##[debug] start updating device script [$displayName]."

                $changedSettings = 0
                $cDeviceScript = Get-deviceManagementScript -deviceManagementScriptId $($deviceScript.id)

                ########## Update device script ##########
                $updateScriptJSON = @"
                {
                    "@odata.type": "#microsoft.graph.deviceManagementScript",
                    "displayName": "<displayName>",
                    "description": "<description>",
                    "scriptContent": "<scriptContent>",
                    "fileName": "<fileName>",
                    "runAsAccount": "<runAsAccount>",
                    "runAs32Bit": "<runAs32Bit>",
                    "enforceSignatureCheck": false,
                    "roleScopeTagIds": <roleScopeTagIds>
                }
"@
                # Update displayName
                if(-not(!$nDisplayName)){
                    if ($nDisplayName -ne ($nDeviceScript.displayName)){
                        $updateScriptJSON = $updateScriptJSON -replace '<displayName>',$nDisplayName
                        $changedSettings += 1
                        Write-Host "##[debug] displayName updated from [$($cDeviceScript.displayName)] to [$nDisplayName]."
                    }
                    else {
                        $updateScriptJSON = $updateScriptJSON -replace '<displayName>',$($cDeviceScript.displayName)
                        Write-Host "##[debug] displayName already [$($cDeviceScript.displayName)]."
                    }
                } 
                else {
                    $updateScriptJSON = $updateScriptJSON -replace '<displayName>',$($cDeviceScript.displayName)
                }

                # Update description
                if(-not(!$description)){
                    if ($description -ne ($cDeviceScript.description)){
                        $updateScriptJSON = $updateScriptJSON -replace '<description>',$description
                        $changedSettings += 1
                        Write-Host "##[debug] description updated from [$($cDeviceScript.description)] to [$description]."
                    }
                    else {
                        $updateScriptJSON = $updateScriptJSON -replace '<description>',$($cDeviceScript.description)
                        Write-Host "##[debug] description already [$($cDeviceScript.description)]."
                    }
                } 
                else {
                    $updateScriptJSON = $updateScriptJSON -replace '<description>',$($cDeviceScript.description)
                }

                # Update scriptContent
                if(-not(!$detect_B64)){
                    if ($detect_B64 -ne ($cDeviceScript.scriptContent)){
                        $updateScriptJSON = $updateScriptJSON -replace '<scriptContent>',$scriptPath_B64
                        $updateScriptJSON = $updateScriptJSON -replace '<fileName>',$fileName
                        $changedSettings += 1
                        Write-Host "##[debug] device script updated from [$($cDeviceScript.scriptContent)] to [$scriptPath_B64]."
                    }
                    else {
                        $updateScriptJSON = $updateScriptJSON -replace '<scriptContent>',$($cDeviceScript.scriptContent)
                        $updateScriptJSON = $updateScriptJSON -replace '<fileName>',$($cDeviceScript.fileName)
                        Write-Host "##[debug] device script already [$($cDeviceScript.scriptContent)]."
                    }
                } 
                else {
                    $updateScriptJSON = $updateScriptJSON -replace '<scriptContent>',$($cDeviceScript.scriptContent)
                    $updateScriptJSON = $updateScriptJSON -replace '<fileName>',$($cDeviceScript.fileName)
                }

                # Update runAsAccount
                if(-not(!$runAsAccount)){
                    if ($runAsAccount -ne ($cDeviceScript.runAsAccount)){
                        $updateScriptJSON = $updateScriptJSON -replace '<runAsAccount>',$runAsAccount
                        $changedSettings += 1
                        Write-Host "##[debug] runAsAccount updated from [$($cDeviceScript.runAsAccount)] to [$runAsAccount]."
                    }
                    else {
                        $updateScriptJSON = $updateScriptJSON -replace '<runAsAccount>',$($cDeviceScript.runAsAccount)
                        Write-Host "##[debug] runAsAccount already [$($cDeviceScript.runAsAccount)]."
                    }
                } 
                else {
                    $updateScriptJSON = $updateScriptJSON -replace '<runAsAccount>',$($cDeviceScript.runAsAccount)
                }

                # Update runAs32Bit
                if(-not(!$runAs32Bit)){
                    if ($runAs32Bit -ne ($cDeviceScript.runAs32Bit)){
                        $updateScriptJSON = $updateScriptJSON -replace '<runAs32Bit>',$runAs32Bit
                        $changedSettings += 1
                        Write-Host "##[debug] runAs32Bit updated from [$($cDeviceScript.runAs32Bit)] to [$runAs32Bit]."
                    }
                    else {
                        $updateScriptJSON = $updateScriptJSON -replace '<runAs32Bit>',$($cDeviceScript.runAs32Bit)
                        Write-Host "##[debug] runAs32Bit already [$($cDeviceScript.runAs32Bit)]."
                    }
                } 
                else {
                    $updateScriptJSON = $updateScriptJSON -replace '<runAs32Bit>',$($cDeviceScript.runAs32Bit)
                }

                ########## Update scope tags ##########

                # Get current scope tags on device script            
                foreach ($scopeTagId in $($cDeviceScript.roleScopeTagIds)){
                    [array]$cScopeTagIds += $scopeTagId
                }
                                    
                # Get device scope tags to verify if tag id needs to be added, already added or removed
                if((-not(!$scopeTagIds)) -or ($cScopeTagIds -ne 0)){

                    $scopeTagIds | ForEach-Object{
                        if($cScopeTagIds -notcontains $_){
                            [array]$updatedScopeTagIds += $_
                            $changedSettings += 1
                            Write-Host "##[debug] scope tag id [$_] added to [$($cDeviceScript.displayName)]."
                        }
                        else {
                            [array]$updatedScopeTagIds += $_
                            Write-Host "##[debug] scope tag id [$_] already assigned to [$($cDeviceScript.displayName)]."
                        }
                    }
                    $cScopeTagIds | ForEach-Object{
                        if($scopeTagIds -notcontains $_){
                            $changedSettings += 1
                            Write-Host "##[debug] scope tag id [$_] removed from [$($cDeviceScript.displayName)]."
                        }
                    }

                    $scopeTagIdsJSON = $updatedScopeTagIds | ConvertTo-Json

                    if ($updatedScopeTagIds.Count -le 1){
                        $updateScriptJSON = $updateScriptJSON -replace '<roleScopeTagIds>',"[$scopeTagIdsJSON]"
                    }
                    else {
                        $updateScriptJSON = $updateScriptJSON -replace '<roleScopeTagIds>',$scopeTagIdsJSON
                    }
                }
                else {
                    # No scope tags found
                    $updateScriptJSON = $updateScriptJSON -replace '<roleScopeTagIds>',"[]"
                    $changedSettings += 1
                    Write-Host "##[debug] no scope tag id found assign default to [$($cDeviceScript.displayName)]."
                }

                # Update settings on device script
                if ($changedSettings -ne 0){
                    Update-deviceManagementScript -deviceManagementScriptId $($deviceScript.id) -json $updateScriptJSON
                    Write-Host "##[debug] updated [$changedSettings] settings on device script [$($cDeviceScript.displayName)]."
                }  

                ########## Update groupmemberships ##########

                # Get microsoft.graph.groupAssignmentTarget groups on device script
                $cGroupAssignments = (Get-deviceManagementScriptAssignment -deviceManagementScriptId $($deviceScript.id) | `
                Where-Object {$_.target."@odata.type" -eq "#microsoft.graph.groupAssignmentTarget"})

                # Start with logic for microsoft.graph.groupAssignmentTarget
                $groupsJSON = @"
                { 
                    "deviceManagementScriptAssignments":[
                    ]
                }
"@
                # Convert from JSON to PowerShell to have a template that can be filled
                $g = $groupsJSON | ConvertFrom-Json

                # When new included group(s) are found
                if(-not(!$nIncludedGroups)){

                    # Add microsoft.graph.groupAssignmentTarget groups
                    $nIncludedGroups | ForEach-Object{
                        if($cGroupAssignments -notcontains $($_.id)){

                            $groupAddJSON = @"
                            {
                                "target":{
                                    "@odata.type":"#microsoft.graph.groupAssignmentTarget",
                                    "groupId":"$($_.id)"
                                }
                            }
"@
                            # Convert from JSON to PowerShell to add targets to deviceManagementScriptAssignments
                            $ga = $groupAddJSON | ConvertFrom-Json
                            $g.deviceManagementScriptAssignments += $ga

                            Write-Host "##[debug] group [$($_.displayName)] added as included group to [$($deviceScript.displayName)]."
                        }
                    }
                }

                if(-not(!$cGroupAssignments)){

                    $cGroupAssignments | ForEach-Object{
                        $group = Get-Group -id $($_.target.groupId)

                        if($($nIncludedGroups.id) -contains $($_.target.groupId)){

                            $groupAddJSON = @"
                            {
                                "target":{
                                    "@odata.type":"#microsoft.graph.groupAssignmentTarget",
                                    "groupId":"$($_.target.groupId)"
                                }
                            }
"@
                            # Convert from JSON to PowerShell to add targets to deviceManagementScriptAssignments that are already assigned
                            $ga = $groupAddJSON | ConvertFrom-Json
                            $g.deviceManagementScriptAssignments += $ga

                            Write-Host "##[debug] group [$($group.displayName)] already an included group on [$($deviceScript.displayName)]."
                        }
                        else {
                            Write-Host "##[debug] group [$($group.displayName)] removed as included group from [$($deviceScript.displayName)]."
                        }
                    }
                }

                # Update group assignments
                Set-deviceManagementScriptAssignment -deviceManagementScriptId $($deviceScript.id) -json $groupsJSON
            }
            else {
                throw "device script with displayName [$displayName] does not exist."              
            }
        }

        #################### Remove device script block ####################

        if($action -eq "remove"){

            # When deviceManagementScript is found continue to remove it
            if(-not(!$deviceScript)){
                Write-Host "##[debug] start removing device script [$displayName]."

                # Remove device script
                Remove-deviceManagementScript -deviceManagementScriptId $($deviceScript.id)
                Write-Host "##[debug] device script [$displayName] removed."
            }
            else {
                throw "device script with displayName [$displayName] does not exist."
            }
        }
    }
}