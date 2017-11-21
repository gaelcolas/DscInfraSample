Write-Warning "---------->> Starting Configuration"

configuration "RootConfiguration"
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    #That Module is a configuration, should be defined in Configuration.psd1
    Import-DscResource -ModuleName SharedDscConfig -ModuleVersion 0.0.3
    Import-DscResource -ModuleName Chocolatey -ModuleVersion 0.0.31

    node $ConfigurationData.AllNodes.NodeName {

        (Lookup $Node 'Configurations') | % {
            $ConfigurationName = $_
            $(Write-Warning "Looking up params for $ConfigurationName")
            $Properties = $(lookup $Node $ConfigurationName -Verbose -DefaultValue @{})
            #x $ConfigurationName $ConfigurationName $Properties
            Get-DscSplattedResource -ResourceName $ConfigurationName -ExecutionName $ConfigurationName -Properties $Properties
        }
        #>
    }
}

RootConfiguration -ConfigurationData $ConfigurationData -Out "$BuildRoot\BuildOutput\MOF\"
