@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath = $True
        Target = 'Configurations'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    'gaelcolas/sharedDscConfig' = 'composite'
}