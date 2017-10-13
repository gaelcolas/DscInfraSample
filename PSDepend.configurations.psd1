@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath = $True
        Target = 'RequiredConfigurations'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    'gaelcolas/sharedDscConfig' = 'master'
}