Param (
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath (Join-Path $PSScriptRoot '../..' -resolve -EA 0)),
    
    [String]
    $BuildOutput = "DscBuildOutput",
    
    [String]
    $ResourcesFolder = "Resources",
    
    [String]
    $ConfigurationsFolder = "Configurations",

    $Environment = 'DEV'

)

Task LoadConfigData {
    if ( ![io.path]::IsPathRooted($BuildOutput) ) {
        $BuildOutput = Join-Path $ProjectPath.FullName -ChildPath $BuildOutput
    }

    $ConfigDataPath = $ProjectPath

    Push-Location $ConfigDataPath
    Import-Module PowerShell-Yaml -scope Global
    Import-Module Datum -Force -Scope Global

    $ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
    $ResourcePath = Join-Path $ProjectPath $ResourcesFolder

    Write-Warning "Configuration Path => $ConfigurationPath"

    if($ConfigurationPath -notin ($Env:PSModulePath -split ';')) {
        $Env:PSModulePath += ';'+$ConfigurationPath
    }

    if($ResourcePath -notin ($Env:PSModulePath -split ';')) {
        $Env:PSModulePath += ';'+$resourcePath
    }

    $Yml = Get-Content -raw $ConfigDataPath\Datum.yml | ConvertFrom-Yaml

    $Global:Datum = New-DatumStructure $Yml

    $Global:ConfigurationData = @{
        AllNodes = @($Global:Datum.ALlNodes.($Environment).psobject.Properties | % { $Datum.AllNodes.($Environment).($_.Name) })
        Datum = $Global:Datum
    }

    $Node = $ConfigurationData.AllNodes[0]
    Write-warning (Lookup $Node 'Configurations' -verbose)

    . ../../RootConfiguration.ps1

    Pop-Location
}