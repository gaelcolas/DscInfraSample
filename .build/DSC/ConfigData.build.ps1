param (
    [System.IO.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),
    
    [String]
    $BuildOutput = (property BuildOutput 'BuildOutput'),
    
    [String]
    $ResourcesFolder = (property ResourcesFolder 'DSC_Resources'),
    
    [String]
    $ConfigurationsFolder = (property ConfigurationsFolder 'DSC_Configurations'),

    [ScriptBlock]
    $Filter = (property Filter {}),

    [String]
    $Environment = (property Environment 'DEV'),

    [String]
    $ConfigDataFolder = (property ConfigDataFolder 'DSC_ConfigData'),

    [String]
    $BuildVersion = (property BuildVersion '0.0.0'),

    [String]
    $RsopFolder = (property RsopFolder 'RSOP'),

    [String[]]
    $ModuleToLeaveLoaded = (property ModuleToLeaveLoaded @('InvokeBuild', 'PSReadline', 'PackageManagement', 'ISESteroids') )
)

task PSModulePath_BuildModules {
    if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
    }

    $configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
    $resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
    $buildModulesPath = Join-Path -Path $BuildOutput -ChildPath 'modules'
        
    Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($configurationPath, $resourcePath, $buildModulesPath)
}

task Load_Datum_ConfigData {
    if (![System.IO.Path]::IsPathRooted($BuildOutput))
    {
        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
    }
    $configDataPath = Join-Path -Path $ProjectPath -ChildPath $ConfigDataFolder
    $configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
    $resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
    $buildModulesPath = Join-Path -Path $BuildOutput -ChildPath 'modules'
        
    Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($configurationPath, $resourcePath, $buildModulesPath)

    Import-Module -Name PowerShell-Yaml -Scope Global
    Import-Module -Name Datum -Force -Scope Global

    $DatumDefinitionFile = Join-Path -Resolve -Path $configDataPath -ChildPath 'Datum.yml'
    Write-Build Green "Loading Datum Definition from $DatumDefinitionFile"
    $Global:Datum = New-DatumStructure -DefinitionFile $DatumDefinitionFile
        

    $Global:ConfigurationData = Get-FilteredConfigurationData -Environment $Environment -Filter $Filter -Datum $Datum
}

task Compile_Root_Configuration {
    $Configurationdata = Get-FilteredConfigurationData -Environment $Environment -Filter $Filter

    try 
    {
        . (Join-Path -Path $ProjectPath -ChildPath 'RootConfiguration.ps1')
    }
    catch 
    {
        Write-Build Red "ERROR OCCURED DURING COMPILATION: $($_.Exception.Message)"
        Write-Build Red ($Error[0] | Out-String)
    }
}

task Compile_Root_Meta_Mof {
    . (Join-Path -Path $ProjectPath -ChildPath 'RootMetaMof.ps1')
    RootMetaMOF -ConfigurationData $Configurationdata -OutputPath (Join-Path -Path $BuildOutput -ChildPath 'MetaMof')
}

task Create_Mof_Checksums {
    Import-Module -Name DscBuildHelpers -Scope Global
    New-DscChecksum -Path (Join-Path -Path $BuildOutput -ChildPath MOF) -Verbose:$false
}

task Compile_Datum_Rsop {
    if(![System.IO.Path]::IsPathRooted($rsopFolder)) {
        $rsopOutputPath = Join-Path -Path $BuildOutput -ChildPath $rsopFolder
    }
    else {
        $RsopOutputPath = $rsopFolder
    }

    if(!(Test-Path -Path $rsopOutputPath)) {
        mkdir -Path $rsopOutputPath -Force | Out-Null
    }

    $rsopOutputPathVersion = Join-Path -Path $RsopOutputPath -ChildPath $BuildVersion
    if(!(Test-Path -Path $rsopOutputPathVersion)) {
        mkdir -Path $rsopOutputPathVersion -Force | Out-Null
    }

    $ConfigurationData.AllNodes.Foreach{
        $nodeRSOP = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{} + $_)
        $nodeRSOP | Convertto-Yaml -OutFile (Join-Path -Path $rsopOutputPathVersion -ChildPath "$($_.Name).yml") -Force
    }
}