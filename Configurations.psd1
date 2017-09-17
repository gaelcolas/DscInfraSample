@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath = $True
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    'gaelcolas/sharedDscConfig' = 'master'
}