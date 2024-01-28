function remove-logicapp-resources {
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$rgName,
        [Parameter(Mandatory=$false)]
        [string]$apiConnection,
        [Parameter(Mandatory=$false)]
        [string]$logicApp
    )

    begin {
        $PSDefaultParameterValues = @{}
    }

    process {
        if($apiConnection){
            $apiConnectionFound = Get-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName $rgName -ResourceName $apiConnection
        
            if($apiConnectionFound){
                Write-Host "##[debug] API connection [$apiConnection] found!"

                try {                            
                    $InRemovedState = ""
                    $Condition = ($InRemovedState -eq $true)
                    
                    while (!$Condition){
                    if ($lastRemovedState -ne $InRemovedState){
                        Write-Host "##[debug] API connection [$apiConnection] not deleted yet (waiting for state change)."
                    }
                        $lastRemovedState = $InRemovedState
                        Start-Sleep -Seconds 5
                        $InRemovedState = Remove-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName $rgName -ResourceName $apiConnection -Force
                        $Condition = ($InRemovedState -eq $true)
                    }
                        
                    Write-Host "##[debug] API connection [$apiConnection] removed."
                } 
                catch {
                    Write-Error $_
                }
            }
            else {
                Write-Host "##[debug] API connection [$apiConnection] is not found."
            }
        }
        else {
            Write-Host "##[debug] No API connection specified."
        }

        if($logicApp){
            $logicAppFound = Get-AzResource -Name $logicApp -ResourceGroupName $rgName
        
            if($logicAppFound){
                Write-Host "##[debug] LogicApp [$logicApp] found!"

                try {                            
                    $InRemovedState = ""
                    $Condition = ($InRemovedState -eq $true)
                    
                    while (!$Condition){
                    if ($lastRemovedState -ne $InRemovedState){
                        Write-Host "##[debug] LogicApp [$logicApp] not deleted yet (waiting for state change)."
                    }
                        $lastRemovedState = $InRemovedState
                        Start-Sleep -Seconds 5
                        $InRemovedState = Remove-AzResource -ResourceType "Microsoft.Logic/workflows" -ResourceGroupName $rgName -Name $logicApp -Force   
                        $Condition = ($InRemovedState -eq $true)
                    }

                    Write-Host "##[debug] LogicApp [$logicApp] removed."
                } 
                catch {
                    Write-Error $_
                }       
            }
            else {
                Write-Host "##[debug] LogicApp [$logicApp] is not found."
            }
        }
        else {
            Write-Host "##[debug] No LogicApp specified." 
        }
    }
}