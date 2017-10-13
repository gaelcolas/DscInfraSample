@{
    #PSDepend dependencies
    
    PSDependOptions = @{
        AddToPath = $True
        Target = 'RequiredResources'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    'gaelcolas/chocolatey' = 'master'
}