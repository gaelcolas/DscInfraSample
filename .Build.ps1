Param (
    [String]
    $BuildOutput = "DscBuildOutput",
    
    [String]
    $ResourcesFolder = "Resources",
    
    [String]
    $ConfigurationsFolder = "Configurations",

    $Environment = 'DEV',

    [String[]]
    $GalleryRepository, #used in ResolveDependencies, has default

    [Uri]
    $GalleryProxy, #used in ResolveDependencies, $null if not specified

    [Switch]
    $ForceEnvironmentVariables = [switch]$true,

    [Parameter(Position=0)]
    $Tasks,

    [switch]
    $ResolveDependency
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
    
    if ($Env:PSModulePath -notcontains $PSScriptRoot) {
        $Env:PSModulePath += ';'+"$PSScriptRoot\$BuildOutput;"+"$PSSCriptRoot\$BuildOutput\modules"
    }

    
    task . DscCleanOutput,test,LoadResource,LoadConfigurations,loadConfigData

    task LoadResource {
        Invoke-PSDepend -Path .\Resources.psd1 -Confirm:$False
    }

    task LoadConfigurations {
        Invoke-PSDepend -Path .\Configurations.psd1 -Confirm:$False
    }

    task DscCleanOutput {
        Get-ChildItem -Path "$BuildOutput" -Recurse | Remove-Item -force -Recurse -Exclude README.md
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
            Path = "$PSScriptRoot\Dependencies.psd1"
        }
        if($PSBoundParameters.ContainsKey('verbose')) { $PSDependParams.add('verbose',$verbose)}
        Invoke-PSDepend @PSDependParams
        Write-Verbose "Project Bootstrapped, returning to Invoke-Build"
    }

    if ($ResolveDependency) {
        Resolve-Dependency
    }
}