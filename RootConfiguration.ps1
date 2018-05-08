$Error.Clear()
if($Env:BuildVersion) {$BuildVersion = $Env:BuildVersion}
elseif($gitshortid = (& git rev-parse --short HEAD)) {$BuildVersion = $gitshortid}
else { $BuildVersion = '0.0.0' }
$goodPSModulePath = $Env:PSModulePath

configuration "RootConfiguration"
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharedDscConfig -ModuleVersion 0.0.4


    $module = Get-Module PSDesiredStateConfiguration
    $null = & $module {param($tag,$Env) Set-PSTopConfigurationName "MOF_$($Env)_$($tag)"} "$BuildVersion",$Environment

    node $ConfigurationData.AllNodes.NodeName {
        Write-Host "`r`n$('-'*75)`r`n$($Node.Name) : $($Node.NodeName) : $(&$module { Get-PSTopConfigurationName })" -ForegroundColor Yellow
        $env:PSModulePath = $goodPSModulePath
        (Lookup 'Configurations').Foreach{
            $configurationName = $_
            $(Write-Debug "`tLooking up params for $configurationName")
            $properties = $(lookup $configurationName -DefaultValue @{})
            $dscError = [System.Collections.ArrayList]::new()
            Get-DscSplattedResource -ResourceName $configurationName -ExecutionName $configurationName -Properties $properties
            if($Error[0] -and $lastError -ne $Error[0]) {
                $lastIndex = [Math]::Max( ($Error.LastIndexOf($lastError) -1), -1)
                if($lastIndex -gt 0) {
                    $Error[0..$lastIndex].Foreach{
                        if($message = Get-DscErrorMessage -Exception $_.Exception) {
                            $null = $dscError.Add($message)
                        }
                    }
                }
                else {
                    if($message = Get-DscErrorMessage -Exception $Error[0].Exception) {
                        $null = $dscError.Add($message)
                    }
                }
                $lastError = $Error[0]
            }

            if($dscError.Count -gt 0) {
                $warningMessage = "    $($Node.Name) : $($Node.Role) ::> $_ "
                Write-Host ($warningMessage + '.' * (55 - $warningMessage.Length) + 'FAILED') -ForeGroundColor Yellow
                $dscError.Foreach{
                    Write-Host "`t$message" -ForeGroundColor Yellow
                }
            }
            else {
                $okMessage = "    $($Node.Name) : $($Node.Role) ::> $_ "
                Write-Host -ForeGroundColor Green ($okMessage + '.' * (55 -$okMessage.Length) + 'OK')
            }
            $lastCount = $Error.Count
        }
    }
}

RootConfiguration -ConfigurationData $ConfigurationData -OutputPath "$ProjectPath\BuildOutput\MOF\"