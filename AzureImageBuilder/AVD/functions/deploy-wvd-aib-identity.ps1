function deploy-wvd-aib-identity {
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$armFile,
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName,
        [Parameter(Mandatory=$true)]
        [string]$customer,
        [Parameter(Mandatory=$true)]
        [string]$environment,
        [Parameter(Mandatory=$true)]
        [string]$solution,
        [Parameter(Mandatory=$true)]
        [string]$offer,
        [Parameter(Mandatory=$true)]
        [string]$sku,
        [Parameter(Mandatory=$true)]
        [string]$publisher,
        [Parameter(Mandatory=$true)]
        [string]$generation                              
    )

    begin {
        $PSDefaultParameterValues = @{
            "deploy-wvd-aib-identity:armFile"=".\.json"
          }
    }

    process {
        # Read the environment variables in PowerShell
        $tags = @{"environment"=$environment; "solution"=$solution; "tech"="arm"}
        $rgName = $customer + "-" + $solution + "-" + $environment + "-" + "sig-rg"
        $sig = $customer + $solution + $environment + "sig" 
        $sigImageName = $customer + "-" + $solution + "-" + $environment + "-" + $sku + "-" + "image"
        $managedIdentityName = $customer + "-" + $solution + "-" + $environment + "-" + "aib-mi"
        $imageRoleDefName = $customer + " " + $solution + " " + $environment + " " + "azure image builder"
        $subscriptionId = (Get-AzSubscription -SubscriptionName $subscriptionName).Id

        # Register necessary Resources
        #Register-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview 
        #Get-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

        Get-AzResourceProvider -ProviderNamespace Microsoft.Compute, Microsoft.KeyVault, Microsoft.Storage, Microsoft.VirtualMachineImages | `
        Where-Object RegistrationState -ne Registered | Register-AzResourceProvider

        # Create the resource group if needed
        try {
            Get-AzResourceGroup -Name $rgName -ErrorAction Stop
        } catch {
            New-AzResourceGroup -Name $rgName -Location "westeurope" -Tag $tags

            # Wait till resource group is found
            $runState = ""
            $condition = ($runState -eq "Succeeded")
            while (!$condition){
            if ($lastrunState -ne $runState){
                write-host $rgName "is" $runState "(waiting for state change)"
            }
                $lastrunState = $runState
                Start-Sleep -Seconds 5
                $runState = (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue).ProvisioningState
                $condition = ($runState -eq "Succeeded")       
            }
            Write-host "resource group $rgName created"
        }

        # Create the user-assigned managed identity if needed
        try {
            Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $managedIdentityName -ErrorAction Stop
        } catch {
            New-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $managedIdentityName -Location "westeurope" -ErrorAction Stop
            Start-Sleep -Seconds 10
            Write-host "managed identity $managedIdentityName created"
        }

        # Assign the identity resource and principal ID's to a variable
        $identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $managedIdentityName).PrincipalId

        # Update json file with new values
        ((Get-Content -path $armFile -Raw) -replace '<subscriptionID>',"$subscriptionId") | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<rgName>',"$rgName") | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace 'Azure Image Builder Service Image Creation Role',"$imageRoleDefName") | Set-Content -Path $armFile

        # Verify if role exists else create
        try {
            New-AzRoleDefinition -InputFile $armFile -ErrorAction Stop
            Start-sleep -Seconds 30
            write-host "custom role $imageRoleDefName created"
        } catch {
            write-host "custom role $imageRoleDefName already exists"
        }

        # Grant the custom Azure Image Builder role definition to the managed identity
        $RoleAssignParams = @{
            ObjectId = $identityNamePrincipalId
            RoleDefinitionName = $imageRoleDefName
            Scope = "/subscriptions/$subscriptionId/resourceGroups/$rgName"
        }

        # Assign managed identity to the custom Azure Image Builder role
        try {
            New-AzRoleAssignment @RoleAssignParams -ErrorAction Stop
            Start-sleep -Seconds 30
            write-host "managed identity $managedIdentityName assigned to custom role $RoleDefinitionName"
        } catch {
            write-host "managed identity $managedIdentityName already assigned to custom role $RoleDefinitionName"
        }

        # Grant the Managed Identity Operator role definition to the managed identity
        $RoleAssignParams = @{
            ObjectId = $identityNamePrincipalId
            RoleDefinitionName = "Managed Identity Operator"
            Scope = "/subscriptions/$subscriptionId/resourceGroups/$rgName"
        }

        # Assign managed identity to the Managed Identity Operator role
        try {
            New-AzRoleAssignment @RoleAssignParams -ErrorAction Stop
            Start-sleep -Seconds 30
            write-host "managed identity $managedIdentityName assigned to role Managed Identity Operator"
        } catch {
            write-host "managed identity $managedIdentityName already assigned to role Managed Identity Operator"
        }

        # Create the Azure Compute Gallery if needed
        try {
            Get-AzGallery -GalleryName $sig -ResourceGroupName $rgName -ErrorAction Stop
        } catch {
            New-AzGallery -GalleryName $sig -ResourceGroupName $rgName -Location "westeurope"

            # Wait till Azure Compute Gallery is found
            $runState = ""
            $condition = ($runState -eq "Succeeded")
            while (!$condition){
            if ($lastrunState -ne $runState){
                write-host $sig "is" $runState "(waiting for state change)"
            }
                $lastrunState = $runState
                Start-Sleep -Seconds 5
                $runState = (Get-AzGallery -GalleryName $sig -ResourceGroupName $rgName -ErrorAction SilentlyContinue).ProvisioningState
                $condition = ($runState -eq "Succeeded")       
            }
            Write-host "azure compute gallery $sig created"
        }

        # Create the VM Image Definition if needed
        try {
            Get-AzGalleryImageDefinition -GalleryName $sig -ResourceGroupName $rgName -Name $sigImageName -ErrorAction Stop
        } catch {
            New-AzGalleryImageDefinition -GalleryName $sig -ResourceGroupName $rgName -Location "westeurope" -Name $sigImageName `
            -HyperVGeneration $generation -OsState generalized -OsType Windows -Publisher $publisher -Offer $offer -Sku $sku -ErrorAction Stop

            # Wait till the VM Image Definition is found
            $runState = ""
            $condition = ($runState -eq "Succeeded")
            while (!$condition){
            if ($lastrunState -ne $runState){
                write-host $sigImageName "is" $runState "(waiting for state change)"
            }
                $lastrunState = $runState
                Start-Sleep -Seconds 5
                $runState = (Get-AzGalleryImageDefinition -GalleryName $sig -ResourceGroupName $rgName -Name $sigImageName -ErrorAction SilentlyContinue).ProvisioningState
                $condition = ($runState -eq "Succeeded")       
            }
            Write-host "gallery image definition $sigImageName created"
        }
    }
}