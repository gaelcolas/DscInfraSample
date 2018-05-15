@{
    #PSDepend dependencies
    
    PSDependOptions              = @{
        AddToPath  = $True
        Target     = 'DSC_Resources'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    chocolatey                   = '0.0.48'
    xPSDesiredStateConfiguration = '8.2.0.0'
}