@{
    #PSDepend dependencies
    
    PSDependOptions = @{
        AddToPath = $True
        Target = 'resources'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    'gaelcolas/chocolatey' = 'master'
}