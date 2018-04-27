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
            $ConfigurationName = $_
            $(Write-Debug "`tLooking up params for $ConfigurationName")
            $Properties = $(lookup $ConfigurationName -DefaultValue @{})
            $DscError = [System.Collections.ArrayList]::new()
            Get-DscSplattedResource -ResourceName $ConfigurationName -ExecutionName $ConfigurationName -Properties $Properties
            $(
                if($Error[0] -and $lastError -ne $Error[0]) {
                    $lastIndex = [Math]::Max( ($Error.LastIndexOf($lastError) -1), -1)
                    if($lastIndex -gt 0) {
                        $Error[0..$lastIndex].Foreach{
                            if($message = Get-DscErrorMessage -Exception $_) {
                                $null = $DscError.Add($message)
                            }
                        }
                    }
                    else {
                        if($Message = Get-DscErrorMessage -Exception $Error[0]) {
                            $null = $DscError.Add($Message)
                        }
                    }
                    $lastError = $Error[0]
                }

                if($DscError.count -gt 0) {
                    $FailMessage = "    $($Node.Name) : $($Node.Role) ::> $_ "
                    Write-Host -ForeGroundColor Red ($FailMessage + '.' * (55 - $FailMessage.Length) + 'FAILED')
                    $DscError.Foreach{
                        Write-Host -ForeGroundColor Yellow "`t$Message"
                    }
                }
                else {
                    $OkMessage = "    $($Node.Name) : $($Node.Role) ::> $_ "
                    Write-Host -ForeGroundColor Green ($OkMessage + '.' * (55 -$OkMessage.Length) + 'OK')
                }
                $LastCount = $Error.Count
            )
        }
    }
}

RootConfiguration -ConfigurationData $ConfigurationData -Out "$BuildRoot\BuildOutput\MOF\" -ErrorAction Stop
