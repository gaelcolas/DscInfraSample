Param (

    [String]
    $BuildOutput = "BuildOutput",
    
    [String]
    $ResourcesFolder = "DSC_Resources",

    [string]
    $DscConfigDataFolder = 'DSC_ConfigData',
    
    [String]
    $ConfigurationsFolder = "DSC_Configurations",

    $Environment = $(if ($BR = (&git @('rev-parse', '--abbrev-ref', 'HEAD')) -and (Test-Path ".\$DscConfigDataFolder\AllNodes\$BR")) { $BR } else {'DEV'} ),

    [String[]]
    $GalleryRepository, #used in ResolveDependencies, has default

    [Uri]
    $GalleryProxy, #used in ResolveDependencies, $null if not specified

    [Switch]
    $ForceEnvironmentVariables = [switch]$true,

    [Parameter(Position=0)]
    $Tasks,

    [switch]
    $ResolveDependency,


    $ProjectPath = $BuildRoot
)

Process {

    if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
        return
    }


    Get-ChildItem -Path "$PSScriptRoot/.build/" -Recurse -Include *.ps1 -Verbose |
        Foreach-Object {
            "Importing file $($_.BaseName)" | Write-Verbose
            . $_.FullName 
        }
    Write-Host $ConfigurationsFolder

    #task . DscCleanOutput,test,loadConfigData
    task . Clean,PSModulePath_BuildModules,test,LoadResource,LoadConfigurations,loadConfigData
    
    $ConfigurationPath = Join-Path $ProjectPath $ConfigurationsFolder
    $ResourcePath = Join-Path $ProjectPath $ResourcesFolder

    task LoadResource {
        $PSDependResourceDefinition = '.\PSDepend.resources.psd1'
        if(Test-Path $PSDependResourceDefinition) {
            Invoke-PSDepend -Path $PSDependResourceDefinition -Confirm:$False -Target $ResourcePath
        }
    }

    task LoadConfigurations {
        $PSDependConfigurationDefinition = '.\PSDepend.configurations.psd1'
        if(Test-Path $PSDependConfigurationDefinition) {
            Invoke-PSDepend -Path $PSDependConfigurationDefinition -Confirm:$False -Target $ConfigurationPath
        }
    }

    task DscCleanResourcesFolder {
        Get-ChildItem -Path "$ResourcesFolder" -Recurse | Remove-Item -force -Recurse -Exclude README.md
    }

    task DscCleanConfigurationsFolder {
        Get-ChildItem -Path "$ConfigurationsFolder" -Recurse | Remove-Item -force -Recurse -Exclude README.md
    }
    

    task test {
        Write-Host (Get-Module Datum,DscBuildHelpers,Pester,PSSscriptAnalyser,PSDeploy -ListAvailable | FT -a | Out-String) 
    }

}

begin {
    function Resolve-Dependency {
        [CmdletBinding()]
        param()

        if (!(Get-PackageProvider -Name NuGet -ForceBootstrap)) {
            $providerBootstrapParams = @{
                Name = 'nuget'
                force = $true
                ForceBootstrap = $true
            }
            if($PSBoundParameters.ContainsKey('verbose')) { $providerBootstrapParams.add('verbose',$verbose)}
            if ($GalleryProxy) { $providerBootstrapParams.Add('Proxy',$GalleryProxy) }
            $null = Install-PackageProvider @providerBootstrapParams
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        if (!(Get-Module -Listavailable PSDepend)) {
            Write-verbose "BootStrapping PSDepend"
            "Parameter $BuildOutput"| Write-verbose
            $InstallPSDependParams = @{
                Name = 'PSDepend'
                AllowClobber = $true
                Confirm = $false
                Force = $true
                Scope = 'CurrentUser'
            }
            if($PSBoundParameters.ContainsKey('verbose')) { $InstallPSDependParams.add('verbose',$verbose)}
            if ($GalleryRepository) { $InstallPSDependParams.Add('Repository',$GalleryRepository) }
            if ($GalleryProxy)      { $InstallPSDependParams.Add('Proxy',$GalleryProxy) }
            if ($GalleryCredential) { $InstallPSDependParams.Add('ProxyCredential',$GalleryCredential) }
            Install-Module @InstallPSDependParams
        }

        $PSDependParams = @{
            Force = $true
            Path = "$PSScriptRoot\PSDepend.build.psd1"
        }
        if($PSBoundParameters.ContainsKey('verbose')) { $PSDependParams.add('verbose',$verbose)}
        Invoke-PSDepend @PSDependParams
        Write-Verbose "Project Bootstrapped, returning to Invoke-Build"
    }

    if ($ResolveDependency) {
        Resolve-Dependency
    }
}