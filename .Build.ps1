[CmdletBinding()]
param (
    [String]
    $buildOutput = 'BuildOutput',
    
    [String]
    $ResourcesFolder = 'DSC_Resources',

    [String]
    $ConfigDataFolder = 'DSC_ConfigData',
    
    [String]
    $ConfigurationsFolder = 'DSC_Configurations',

    [String]
    $TestFolder = 'Tests',

    [ScriptBlock]
    $Filter = {},

    [int]$MofCompilationTaskCount,
    
    [switch]$RandomWait,

    $Environment = $(
        $branch = $env:BranchName
        $branch = if ($branch -eq 'master')
        { 'Prod' 
        }
        else
        { 'Dev' 
        }
        if (Test-Path -Path ".\$ConfigDataFolder\AllNodes\$branch")
        {
            $branch
        }
        else
        {
            'Dev'
        }
    ),
    
    $BuildVersion = $(
        if ($gitshortid = (& git rev-parse --short HEAD))
        {$gitshortid
        }
        else
        {'0.0.0' 
        }
    ),

    [String[]]
    $GalleryRepository, #used in ResolveDependencies, has default

    [Uri]
    $GalleryProxy, #used in ResolveDependencies, $null if not specified

    [Switch]
    $ForceEnvironmentVariables = $true,

    [Parameter(Position = 0)]
    $Tasks,

    [Switch]
    $ResolveDependency,

    [String]
    $ProjectPath,

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

function Split-Array
{
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$List,

        [Parameter(Mandatory, ParameterSetName = 'ChunkSize')]
        [int]$ChunkSize,
        
        [Parameter(Mandatory, ParameterSetName = 'ChunkCount')]
        [int]$ChunkCount
    )
    $aggregateList = @()
    
    if ($ChunkCount)
    {
        $ChunkSize = [Math]::Ceiling($List.Count / $ChunkCount)
    }

    $blocks = [Math]::Floor($List.Count / $ChunkSize)
    $leftOver = $List.Count % $ChunkSize
    for ($i = 0; $i -lt $blocks; $i++)
    {
        $end = $ChunkSize * ($i + 1) - 1

        $aggregateList += @(, $List[$start..$end])
        $start = $end + 1
    }    
    if ($leftOver -gt 0)
    {
        $aggregateList += @(, $List[$start..($end + $leftOver)])
    }

    , $aggregateList    
}
function Resolve-Dependency
{
    [CmdletBinding()]
    param()

    Write-Host "Downloading dependencies, this may take a while" -ForegroundColor Green
    if (!(Get-PackageProvider -Name NuGet -ForceBootstrap))
    {
        $providerBootstrapParams = @{
            Name           = 'nuget'
            force          = $true
            ForceBootstrap = $true
        }
        if ($PSBoundParameters.ContainsKey('Verbose'))
        {
            $providerBootstrapParams.Add('Verbose', $Verbose)
        }
        if ($GalleryProxy)
        {
            $providerBootstrapParams.Add('Proxy', $GalleryProxy)
        }
        $null = Install-PackageProvider @providerBootstrapParams
        #Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
        
    Write-Verbose -Message 'BootStrapping PSDepend'
    Write-Verbose -Message "Parameter $buildOutput"
    $installPSDependParams = @{
        Name    = 'PSDepend'
        Path    = $buildModulesPath
        Confirm = $false
    }
    if ($PSBoundParameters.ContainsKey('verbose'))
    {
        $installPSDependParams.Add('Verbose', $Verbose)
    }
    if ($GalleryRepository)
    {
        $installPSDependParams.Add('Repository', $GalleryRepository)
    }
    if ($GalleryProxy)
    {
        $installPSDependParams.Add('Proxy', $GalleryProxy)
    }
    if ($GalleryCredential)
    {
        $installPSDependParams.Add('ProxyCredential', $GalleryCredential)
    }
    Save-Module @installPSDependParams

    $PSDependParams = @{
        Force = $true
        Path  = "$ProjectPath\PSDepend.Build.psd1"
    }
    if ($PSBoundParameters.ContainsKey('Verbose'))
    {
        $PSDependParams.add('Verbose', $Verbose)
    }
    Invoke-PSDepend @PSDependParams
    Write-Verbose 'Project Bootstrapped, returning to Invoke-Build'
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#cannot be a default parameter value due to https://github.com/PowerShell/PowerShell/issues/4688
if (-not $ProjectPath)
{
    $ProjectPath = $PSScriptRoot
}

if (!([System.IO.Path]::IsPathRooted($buildOutput)))
{
    $buildOutput = Join-Path -Path $ProjectPath -ChildPath $buildOutput
}

$buildModulesPath = Join-Path -Path $buildOutput -ChildPath 'Modules'
if (!(Test-Path -Path $buildModulesPath))
{
    $null = mkdir -Path $buildModulesPath -Force
}

if ($buildModulesPath -notin ($Env:PSModulePath -split ';'))
{
    $env:PSModulePath = "$buildModulesPath;$Env:PSModulePath"
}

if ($ResolveDependency)
{
    Resolve-Dependency
}

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
        Invoke-Build -Tasks $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
            
        if ($MofCompilationTaskCount)
        {
            $global:splittedNodes = Split-Array -List $ConfigurationData.AllNodes -ChunkCount $MofCompilationTaskCount
            
            if ($MofCompilationTaskCount)
            {
                $mofCompilationTasks = foreach ($nodeSet in $global:splittedNodes)
                {
                    $nodeNamesInSet = "'$($nodeSet.Name -join "', '")'"
                    $filterString = '$_.NodeName -in {0}' -f $nodeNamesInSet
                    $PSBoundParameters.Filter = [scriptblock]::Create($filterString)
                
                    @{ 
                        File                 = $MyInvocation.MyCommand.Path
                        Task                 = 'PSModulePath_BuildModules',
                        'Load_Datum_ConfigData',
                        'Compile_Datum_Rsop',
                        'Compile_Root_Configuration',
                        'Compile_Root_Meta_Mof'
                        Filter               = [scriptblock]::Create($filterString)
                        RandomWait           = $true
                        BuildOutput          = $buildOutput
                        ResourcesFolder      = $ResourcesFolder
                        ConfigDataFolder     = $ConfigDataFolder
                        ConfigurationsFolder = $ConfigurationsFolder
                        TestFolder           = $TestFolder
                        Environment          = $Environment
                    }
                }
                Build-Parallel $mofCompilationTasks
            }
        }
        return
    }
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

if ($MofCompilationTaskCount)
{
    task . Clean_BuildOutput, 
    Download_All_Dependencies, 
    PSModulePath_BuildModules, 
    Test_ConfigData,
    Load_Datum_ConfigData    
    #Create_Mof_Checksums, # or use the meta-task: Compile_Datum_DSC,
    #Zip_Modules_For_Pull_Server
}
else
{
    task . Clean_BuildOutput,
    Download_All_Dependencies,
    PSModulePath_BuildModules,
    Test_ConfigData,
    Load_Datum_ConfigData,
    Compile_Datum_Rsop,
    Compile_Root_Configuration,
    Compile_Root_Meta_Mof
    #Create_Mof_Checksums, # or use the meta-task: Compile_Datum_DSC,
    #Zip_Modules_For_Pull_Server
    #Deployment
}

task Download_All_Dependencies -if ($DownloadResourcesAndConfigurations -or $Tasks -contains 'Download_All_Dependencies') Download_DSC_Configurations, Download_DSC_Resources
    
$configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
$resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
$configDataPath = Join-Path -Path $ProjectPath -ChildPath $ConfigDataFolder
$testsPath = Join-Path -Path $ProjectPath -ChildPath $TestFolder

task Download_DSC_Resources {
    $PSDependResourceDefinition = "$ProjectPath\PSDepend.DSC_Resources.psd1"
    if (Test-Path $PSDependResourceDefinition)
    {
        Invoke-PSDepend -Path $PSDependResourceDefinition -Confirm:$false -Target $resourcePath
    }
}

task Download_DSC_Configurations {
    $PSDependConfigurationDefinition = "$ProjectPath\PSDepend.DSC_Configurations.psd1"
    if (Test-Path $PSDependConfigurationDefinition)
    {
        Write-Build Green 'Pull dependencies from PSDepend.DSC_Configurations.psd1'
        Invoke-PSDepend -Path $PSDependConfigurationDefinition -Confirm:$false -Target $configurationPath
    }
}

task Clean_DSC_Resources_Folder {
    Get-ChildItem -Path "$ResourcesFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
}

task Clean_DSC_Configurations_Folder {
    Get-ChildItem -Path "$ConfigurationsFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
}

task Zip_Modules_For_Pull_Server {
    if (!([System.IO.Path]::IsPathRooted($buildOutput)))
    {
        $BuildOutput = Join-Path $PSScriptRoot -ChildPath $BuildOutput
    }
    Import-Module DscBuildHelpers -ErrorAction Stop
    Get-ModuleFromfolder -ModuleFolder (Join-Path $ProjectPath -ChildPath $ResourcesFolder) |
        Compress-DscResourceModule -DscBuildOutputModules (Join-Path $BuildOutput -ChildPath 'DscModules') -Verbose:$false 4>$null
}

task Test_ConfigData {
    if (!(Test-Path -Path $testsPath))
    {
        Write-Build Yellow "Path for tests '$testsPath' does not exist"
        return
    }
    if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }
    $testResultsPath = Join-Path -Path $BuildOutput -ChildPath TestResults.xml
    $testResults = Invoke-Pester -Script $testsPath -PassThru -OutputFile $testResultsPath -OutputFormat NUnitXml

    assert ($testResults.FailedCount -eq 0)
}