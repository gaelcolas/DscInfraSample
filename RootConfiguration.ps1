Write-Warning "---------->> Starting Configuration"

configuration "RootConfiguration"
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    #That Module is a configuration, should be defined in Configuration.psd1
    Import-DscResource -ModuleName SharedDscConfig -ModuleVersion 0.0.2

    node $ConfigurationData.AllNodes.NodeName {

        (Lookup $Node 'Configurations') | % {
            $ConfigurationName = $_
            $(Write-Warning "Looking up $ConfigurationName")
            $Properties = $(lookup $Node $ConfigurationName -Verbose -DefaultValue @{})
            $(Write-Warning "Including $($Properties | Convertto-json)")
            #x $ConfigurationName $ConfigurationName $Properties
            Get-DscSplattedResource -ResourceName $ConfigurationName -ExecutionName $ConfigurationName -Properties $Properties
        }
        #>
    }
}

RootConfiguration -ConfigurationData $ConfigurationData -Out ".\DscBuildOutput\MOF\$($Environment)\"
