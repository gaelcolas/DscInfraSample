param (
    [String]
    $BuildOutput = 'BuildOutput',
    
    [String]
    $ResourcesFolder = 'DSC_Resources',

    [String]
    $ConfigDataFolder = 'DSC_ConfigData',
    
    [String]
    $ConfigurationsFolder = 'DSC_Configurations',

    [ScriptBlock]
    $Filter = {},

    $Environment = $(if ($BR = (&git.exe @('rev-parse', '--abbrev-ref', 'HEAD')) -and (Test-Path -Path ".\$ConfigDataFolder\AllNodes\$BR"))
        {
            $BR
        }
        else
        {
            'DEV'
        }
    ),

    [String[]]
    $GalleryRepository, #used in ResolveDependencies, has default

    [Uri]
    $GalleryProxy, #used in ResolveDependencies, $null if not specified

    [Switch]
    $ForceEnvironmentVariables = [switch]$true,

    [Parameter(Position = 0)]
    $Tasks,

    [Switch]
    $ResolveDependency,

    [String]
    $ProjectPath = $BuildRoot,

    [Switch]
    $DownloadResourcesAndConfigurations,

    [Switch]
    $Help,

    [ScriptBlock]
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
        {
            $providerBootstrapParams.add('verbose', $verbose)
        }
        if ($GalleryProxy)
        {
            $providerBootstrapParams.Add('Proxy', $GalleryProxy)
        }
        $null = Install-PackageProvider @providerBootstrapParams
        #Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
        
    Write-Verbose -Message 'BootStrapping PSDepend'
    "Parameter $BuildOutput"| Write-Verbose
    $InstallPSDependParams = @{
        Name    = 'PSDepend'
        Path    = $BuildModulesPath
        Confirm = $false
    }
    if ($PSBoundParameters.ContainsKey('verbose'))
    {
        $InstallPSDependParams.add('verbose', $verbose)
    }
    if ($GalleryRepository)
    {
        $InstallPSDependParams.Add('Repository', $GalleryRepository)
    }
    if ($GalleryProxy)
    {
        $InstallPSDependParams.Add('Proxy', $GalleryProxy)
    }
    if ($GalleryCredential)
    {
        $InstallPSDependParams.Add('ProxyCredential', $GalleryCredential)
    }
    Save-Module @InstallPSDependParams
    

    $PSDependParams = @{
        Force = $true
        Path  = "$PSScriptRoot\PSDepend.build.psd1"
    }
    if ($PSBoundParameters.ContainsKey('verbose'))
    {
        $PSDependParams.add('verbose', $verbose)
    }
    Invoke-PSDepend @PSDependParams
    Write-Verbose 'Project Bootstrapped, returning to Invoke-Build'
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
{
    $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
}

$BuildModulesPath = Join-Path -Path $BuildOutput -ChildPath 'Modules'
if (!(Test-Path $BuildModulesPath))
{
    $null = mkdir $BuildModulesPath -Force
}

if ($BuildModulesPath -notin ($Env:PSModulePath -split ';') )
{
    $Env:PSModulePath = $BuildModulesPath + ';' + $Env:PSModulePath
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
        Invoke-Build.ps1 ?
    }
    else
    {
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
    }
    return
}

Get-ChildItem -Path "$PSScriptRoot/.build/" -Recurse -Include *.ps1 -Verbose |
ForEach-Object {
    "Importing file $($_.BaseName)" | Write-Verbose
    . $_.FullName 
}
    
if ($TaskHeader)
{
    Set-BuildHeader $TaskHeader
}

task . Clean_BuildOutput, 
Download_All_Dependencies, 
PSModulePath_BuildModules, 
Load_Datum_ConfigData,
Compile_Root_Configuration, 
Compile_Root_Meta_Mof,
Create_Mof_Checksums, # or use the meta-task: Compile_Datum_DSC,
Zip_Modules_For_Pull_Server

task Download_All_Dependencies -if ($DownloadResourcesAndConfigurations -or $Tasks -contains 'Download_All_Dependencies') Download_DSC_Configurations, Download_DSC_Resources
    
$ConfigurationPath = Join-Path $ProjectPath -ChildPath $ConfigurationsFolder
$ResourcePath = Join-Path $ProjectPath -ChildPath $ResourcesFolder
$ConfigDataPath = Join-Path $ProjectPath -ChildPath $ConfigDataFolder

task Download_DSC_Resources {
    $PSDependResourceDefinition = '.\PSDepend.DSC_resources.psd1'
    if (Test-Path $PSDependResourceDefinition)
    {
        Invoke-PSDepend -Path $PSDependResourceDefinition -Confirm:$false -Target $ResourcePath
    }
}

task Download_DSC_Configurations {
    $PSDependConfigurationDefinition = '.\PSDepend.DSC_configurations.psd1'
    if (Test-Path $PSDependConfigurationDefinition)
    {
        Write-Build Green 'Pull dependencies from PSDepend.DSC_configurations.psd1'
        Invoke-PSDepend -Path $PSDependConfigurationDefinition -Confirm:$false -Target $ConfigurationPath
    }
}

task Clean_DSC_Resources_Folder {
    Get-ChildItem -Path "$ResourcesFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
}

task Clean_DSC_Configurations_Folder {
    Get-ChildItem -Path "$ConfigurationsFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
}

task Zip_Modules_For_Pull_Server {
    if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path $PSScriptRoot -ChildPath $BuildOutput
    }
    Import-Module DscBuildHelpers -ErrorAction Stop
    Get-ModuleFromfolder -ModuleFolder (Join-Path $ProjectPath -ChildPath $ResourcesFolder) |
    Compress-DscResourceModule -DscBuildOutputModules (Join-Path $BuildOutput -ChildPath 'DscModules') -Verbose:$false 4>$null
}