#PSDepend dependencies
# Either install modules for generic use or save them in ./modules for Test-Kitchen

@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath = $True
        Target = 'BuildOutput\modules'
        Parameters = @{
            #Force = $True
            #ExtractProject = $true
        }
    }

    invokeBuild = 'latest'
    buildhelpers = 'latest'
    pester = 'latest'
    PSScriptAnalyzer = 'latest'
    psdeploy = 'latest'
    xPSDesiredStateConfiguration = 'latest'
    xDscResourceDesigner = 'latest'
    DscBuildHelpers = 'latest'
    Datum = 'latest'
    ProtectedData = 'latest'
    'powershell-yaml' = 'latest'
}
