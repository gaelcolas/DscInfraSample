@{
    #PSDepend dependencies
    
    PSDependOptions = @{
        AddToPath = $True
        Target = 'DSC_Resources'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    'gaelcolas/chocolatey' = 'master'
}