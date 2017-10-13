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

Task LoadConfigData {
    if ( ![io.path]::IsPathRooted($BuildOutput) ) {
        $BuildOutput = Join-Path $ProjectPath -ChildPath $BuildOutput
    }

    $ConfigDataPath = Join-Path $ProjectPath $DscConfigDataFolder

    Push-Location $ConfigDataPath
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

    $Yml = Get-Content -raw (Join-Path $ConfigDataPath 'Datum.yml') | ConvertFrom-Yaml

    $Global:Datum = New-DatumStructure $Yml

    $Global:ConfigurationData = @{
        AllNodes = @($Global:Datum.ALlNodes.($Environment).psobject.Properties | % { $Datum.AllNodes.($Environment).($_.Name) })
        Datum = $Global:Datum
    }

    $Node = $ConfigurationData.AllNodes[0]
    Write-warning (Lookup $Node 'Configurations' -verbose)

    . (Join-path $ProjectPath 'RootConfiguration.ps1')

    Pop-Location
}