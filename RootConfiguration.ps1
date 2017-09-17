if($PSScriptRoot) {
    $here = $PSScriptRoot
} else {
    $here = 'C:\src\DscInfraSample'
}
$Env:PSModulePath = $Env:PSModulePath+';'+"$here\Configurations\"

pushd $here
remove-item function:\Resolve-NodeProperty
remove-item Alias:\Lookup

ipmo Datum -force

$yml = Get-Content -raw $PSScriptRoot\datum.yml | ConvertFrom-Yaml

$datum = New-DatumStructure $yml


$ConfigurationData = @{
    AllNodes = @($Datum.AllNodes.($Environment).psobject.Properties | % { $Datum.AllNodes.($Environment).($_.Name) })
    Datum = $Datum
}

<#
$Node = $Configurationdata.Allnodes.($Environment)[0] #select the first Node for testing

#"Node is $($Node|FL *|Out-String)" | Write-Warning

Lookup -Node $Node -PropertyPath 'Configurations' <#'AllValues' -Verbose -Debug | Write-Warning
#>

Write-Warning "---------->> Starting Configuration"
configuration "RootConfiguration"
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    #That Module is a configuration, should be defined in Configuration.psd1
    Import-DscResource -ModuleName PLATFORM -ModuleVersion 0.0.1

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

#display generated config as example
(cat -raw .\RootConfiguration\DEV\SRV01.mof) -replace '\\n',"`r`n"