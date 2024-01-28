function build-wvd-aib-multi-image {
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$armFile,
        [Parameter(Mandatory=$true)]
        [string]$baselineConfiguration,
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
        [string]$buildNumber
    )

    begin {
        $PSDefaultParameterValues = @{
            "build-wvd-aib-multi-image:armFile"=".\.json"
            "build-wvd-aib-multi-image:baselineConfiguration"=".\.ps1"
          }
    }

    process {
        # Read the environment variables in PowerShell
        $tags = @{"environment"=$environment; "solution"=$solution; "tech"="arm"}
        $rgName = $customer + "-" + $solution + "-" + $environment + "-" + "sig-rg"
        $rgSaName = $customer + "-" + $solution + "-" + $environment + "-" + "storage-rg"
        $saName = $customer + $solution + $environment + "msix"
        $containerName = $customer + $solution + "repo"
        $blobName = "baseline-aib-multi-image.ps1"
        $version = "latest"
        $date = Get-Date -format "yyyyMMdd"
        $sig = $customer + $solution + $environment + "sig"
        $sigImageName = $customer + "-" + $solution + "-" + $environment + "-" + $sku + "-" + "image"
        $managedIdentityName = $customer + "-" + $solution + "-" + $environment + "-" + "aib-mi"
        $imageTemplateName = $customer + "-" + $solution + "-" + $environment + "-" + $sku + "-" + "aib-template" + "-" + $Date
        $apiVersion = "2022-02-14"

        # Construct runOutputName for the image
        Write-Host "Starting process for generating runOutputName for Azure Image Builder"

        $splitNumber = $buildNumber.Split(".")
        if( $splitNumber.Count -eq 6 )
        {
            $majorNumber = $splitNumber[2]
            $minorNumber = $splitNumber[3]
            $date = $splitNumber[4]
            $revisionNumber = $splitNumber[5]
        
            $runOutputName = $majorNumber + "." + $minorNumber + "." + $date + $revisionNumber
            Write-Host "start creating image build $runOutputName"
        }
        else {
            Write-Host "##vso[task.logissue type=warning] the buildnumber is incorrect stop Azure Image Builder process"
            Break
        }

        $imgBuilderId = (Get-AzUserAssignedIdentity -Name $managedIdentityName -ResourceGroupName $rgName).Id
        $sigImageId = (Get-AzGalleryImageDefinition -GalleryName $sig -ResourceGroupName $rgName -Name $sigImageName).Id

        if (!$imgBuilderId){
            Write-Host "##vso[task.logissue type=warning] no azure image builder identity found"
            Break
        }

        if (!$sigImageId){
            Write-Host "##vso[task.logissue type=warning] no gallery or image definition found"
            Break
        }

        # Upload baselineConfiguration to blob storage and generate SAS URL
        $now = Get-Date
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $rgSaName -Name $saName
        $context = $storageAccount.Context
        
        Set-AzStorageBlobContent -File $baselineConfiguration -Container $containerName -Blob $blobName `
        -Context $context -Force
        
        $sasUrl = New-AzStorageBlobSASToken -Container $containerName -Context $Context -Blob $blobName `
        -Permission rwdl -StartTime $now.AddHours(-1) -ExpiryTime $now.AddMonths(1) -FullUri

        ((Get-Content -path $armFile -Raw) -replace '<publisher>',$publisher) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<offer>',$offer) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<sku>',$sku) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<version>',$version) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<galleryImageId>',$sigImageId) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<imgBuilderId>',$imgBuilderId) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<baselineConfiguration>',$sasUrl) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<environment>',$environment) | Set-Content -Path $armFile
        ((Get-Content -path $armFile -Raw) -replace '<solution>',$solution) | Set-Content -Path $armFile

        ## Create a Template Parameter Object (hashtable)
        $objTemplateParameter = @{
        "api-version" = $apiVersion
        "imageTemplateName" = $imageTemplateName;
        "svclocation" = "westeurope";
        }

        # Deploy Azure Image Builder process using ARM template with template parameters from hashtable
        New-AzResourceGroupDeployment -ResourceGroupName $rgName `
        -TemplateFile $armFile `
        -TemplateParameterObject $objTemplateParameter `
        -Tag $tags -Verbose

        # Build the image
        Invoke-AzResourceAction -ResourceName $imageTemplateName `
        -ResourceGroupName $rgName `
        -ResourceType Microsoft.VirtualMachineImages/imageTemplates `
        -ApiVersion $apiVersion `
        -Action Run -Force
    }
}