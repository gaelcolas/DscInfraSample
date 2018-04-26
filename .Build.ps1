Param (

    [String]
    $BuildOutput = "BuildOutput",
    
    [String]
    $ResourcesFolder = "DSC_Resources",

    [string]
    $ConfigDataFolder = 'DSC_ConfigData',
    
    [String]
    $ConfigurationsFolder = "DSC_Configurations",

    [ScriptBlock]
    $Filter = {},

    $Environment = $(if ($BR = (&git @('rev-parse', '--abbrev-ref', 'HEAD')) -and (Test-Path ".\$ConfigDataFolder\AllNodes\$BR"))
        { $BR 
        }
        else
        {'DEV'
        } ),

    [String[]]
    $GalleryRepository, #used in ResolveDependencies, has default

    [Uri]
    $GalleryProxy, #used in ResolveDependencies, $null if not specified

    [Switch]
    $ForceEnvironmentVariables = [switch]$true,

    [Parameter(Position = 0)]
    $Tasks,

    [switch]
    $ResolveDependency,

    $ProjectPath = $BuildRoot,

    [switch]
    $DownloadResourcesAndConfigurations,

    [switch]
    $Help,

    $TaskHeader = {
        Param($Path)
        ''
        '=' * 79
        Write-Build Cyan "`t`t`t$($Task.Name.Replace('_',' ').ToUpper())"
        Write-Build DarkGray "$(Get-BuildSynopsis $Task)"
        '-' * 79
        Write-Build DarkGray "  $Path"
        Write-Build DarkGray "  $($Task.InvocationInfo.ScriptName):$($Task.InvocationInfo.ScriptLineNumber)"
        ''
    }
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

if (!([io.path]::IsPathRooted($BuildOutput)))
{
    $BuildOutput = Join-Path $PSScriptRoot $BuildOutput
}

$BuildModulesPath = Join-Path $BuildOutput 'modules'
if (!(test-Path $BuildModulesPath))
{
    $null = mkdir $BuildModulesPath -force
}

if ($BuildModulesPath -notin ($Env:PSModulePath -split ';') )
{
    $Env:PSmodulePath = $BuildModulesPath + ';' + $Env:PSmodulePath
}

function Resolve-Dependency
{
    [CmdletBinding()]
    param()

    if (!(Get-PackageProvider -Name NuGet -ForceBootstrap))
    {
        $providerBootstrapParams = @{
            Name           = 'nuget'
            force          = $true
            ForceBootstrap = $true
        }
        if ($PSBoundParameters.ContainsKey('verbose'))
        { $providerBootstrapParams.add('verbose', $verbose)
        }
        if ($GalleryProxy)
        { $providerBootstrapParams.Add('Proxy', $GalleryProxy) 
        }
        $null = Install-PackageProvider @providerBootstrapParams
        #Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
        
    Write-verbose "BootStrapping PSDepend"
    "Parameter $BuildOutput"| Write-verbose
    $InstallPSDependParams = @{
        Name    = 'PSDepend'
        Path    = $BuildModulesPath
        Confirm = $false
    }
    if ($PSBoundParameters.ContainsKey('verbose'))
    { $InstallPSDependParams.add('verbose', $verbose)
    }
    if ($GalleryRepository)
    { $InstallPSDependParams.Add('Repository', $GalleryRepository) 
    }
    if ($GalleryProxy)
    { $InstallPSDependParams.Add('Proxy', $GalleryProxy) 
    }
    if ($GalleryCredential)
    { $InstallPSDependParams.Add('ProxyCredential', $GalleryCredential) 
    }
    Save-Module @InstallPSDependParams
    

    $PSDependParams = @{
        Force = $true
        Path  = "$PSScriptRoot\PSDepend.build.psd1"
    }
    if ($PSBoundParameters.ContainsKey('verbose'))
    { $PSDependParams.add('verbose', $verbose)
    }
    Invoke-PSDepend @PSDependParams
    Write-Verbose "Project Bootstrapped, returning to Invoke-Build"
}

if ($ResolveDependency)
{
    Resolve-Dependency
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1')
{
    if ($ResolveDependency -or $PSBoundParameters.ContainsKey('ResolveDependency'))
    {
        $PSBoundParameters.Remove('ResolveDependency')
        $PSBoundParameters.Add('DownloadResourcesAndConfigurations', $true)
    }

    if ($Help)
    {
        Invoke-Build ?
    }
    else
    {
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
    }
    return
}

Get-ChildItem -Path "$PSScriptRoot/.build/" -Recurse -Include *.ps1 -Verbose |
    Foreach-Object {
    "Importing file $($_.BaseName)" | Write-Verbose
    . $_.FullName 
}
    
if ($TaskHeader)
{ Set-BuildHeader $TaskHeader 
}

task .  Clean_BuildOutput,
Download_all_Dependencies,
PSModulePath_BuildModules,
load_datum_configdata,
Compile_Root_Configuration,
compile_root_meta_mof,
create_MOF_checksums, # or use the meta-task: Compile_Datum_DSC,
zip_modules_for_pull_server

task Download_all_Dependencies -if ($DownloadResourcesAndConfigurations -or $Tasks -contains 'Download_all_Dependencies') Download_DSC_Configurations, Download_DSC_Resources
    
$ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
$ResourcePath = Join-Path $ProjectPath $ResourcesFolder
$ConfigDataPath = Join-Path $ProjectPath $ConfigDataFolder

task Download_DSC_Resources {
    $PSDependResourceDefinition = '.\PSDepend.DSC_resources.psd1'
    if (Test-Path $PSDependResourceDefinition)
    {
        Invoke-PSDepend -Path $PSDependResourceDefinition -Confirm:$False -Target $ResourcePath
    }
}

task Download_DSC_Configurations {
    $PSDependConfigurationDefinition = '.\PSDepend.DSC_configurations.psd1'
    if (Test-Path $PSDependConfigurationDefinition)
    {
        Write-Build Green "Pull dependencies from PSDepend.DSC_configurations.psd1"
        Invoke-PSDepend -Path $PSDependConfigurationDefinition -Confirm:$False -Target $ConfigurationPath
    }
}

task Clean_DSC_Resources_Folder {
    Get-ChildItem -Path "$ResourcesFolder" -Recurse | Remove-Item -force -Recurse -Exclude README.md
}

task Clean_DSC_Configurations_Folder {
    Get-ChildItem -Path "$ConfigurationsFolder" -Recurse | Remove-Item -force -Recurse -Exclude README.md
}

task zip_modules_for_pull_server {
    if (!([io.path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path $PSScriptRoot $BuildOutput
    }
    Import-Module DscBuildHelpers -ErrorAction Stop
    Get-ModuleFromfolder -ModuleFolder (Join-Path $ProjectPath $ResourcesFolder) |
        Compress-DscResourceModule -DscBuildOutputModules (Join-Path $BuildOutput 'DscModules') -Verbose:$false 4>$null
}