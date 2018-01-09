Param (
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),
    
    [String]
    $BuildOutput = (property BuildOutput "BuildOutput"),
    
    [String]
    $ResourcesFolder = (property ResourcesFolder "DSC_Resources"),
    
    [String]
    $ConfigurationsFolder =  (property ConfigurationsFolder "DSC_Configurations"),

    $Environment = (property Environment 'DEV'),

    $DscConfigDataFolder = (property DscConfigDataFolder 'DSC_ConfigData')

)
    task PSModulePath_BuildModules {
        $ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
        $ResourcePath = Join-Path $ProjectPath $ResourcesFolder
        $BuildModulesPath = Join-Path $ProjectPath "$BuildOutput\Modules"
        if (($Env:PSModulePath -split ';') -notcontains $ResourcePath) {
            $Env:PSModulePath += ';'+$ResourcePath
        }
        if (($Env:PSModulePath -split ';') -notcontains $ConfigurationPath) {
            $Env:PSModulePath += ';'+$ConfigurationPath
        }
        if (($Env:PSModulePath -split ';') -notcontains $BuildModulesPath) {
            $Env:PSModulePath += ';'+$BuildModulesPath
        }
    }

    Task CompileDSCWithDatum LoadDatumConfigData, CompileRootConfiguration, CompileRootMetaMof, CreateChecksums

    Task LoadDatumConfigData {
        if ( ![io.path]::IsPathRooted($BuildOutput) ) {
            $BuildOutput = Join-Path $ProjectPath -ChildPath $BuildOutput
        }

        $ConfigDataPath = Join-Path $ProjectPath $DscConfigDataFolder

        Import-Module PowerShell-Yaml -scope Global
        Import-Module Datum -Force -Scope Global

        $ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
        $ResourcePath = Join-Path $ProjectPath $ResourcesFolder

        if($ConfigurationPath -notin ($Env:PSModulePath -split ';')) {
            $Env:PSModulePath += ';'+$ConfigurationPath
        }

        if($ResourcePath -notin ($Env:PSModulePath -split ';')) {
            $Env:PSModulePath += ';'+$resourcePath
        }
        $DatumDefinitionFile = Join-Path -Resolve $ConfigDataPath 'Datum.yml'
        $Global:Datum = New-DatumStructure -DefinitionFile $DatumDefinitionFile
        
        $AllNodes = @($Datum.AllNodes.($Environment).psobject.Properties | ForEach-Object { 
        $Node = $Datum.AllNodes.($Environment).($_.Name)
        $null = $Node.Add('Environment',$Environment)
        if(!$Node.contains('Name') ) {
            $null = $Node.Add('Name',$_.Name)
        }
        (@{} + $Node)
    })

    $Global:ConfigurationData = @{
        AllNodes = $AllNodes
        Datum = $Global:Datum
    }
}

task CompileRootConfiguration {
    . (Join-path $ProjectPath 'RootConfiguration.ps1')
}

task CompileRootMetaMof {
    . (Join-path $ProjectPath 'RootMetaMof.ps1')
    RootMetaMOF -ConfigurationData $ConfigurationData -outputPath (Join-Path $BuildOutput 'MetaMof')
}

task CreateChecksums {
    Import-Module DscBuildHelpers -Scope Global
    New-DscChecksum -Path (Join-Path $BuildOutput MOF) -verbose:$false
}