function Get-DscErrorMessage
{
    param(
        $Exception
    )

    switch ($Exception)
    {
        { $_.ToString() -match "Unable to find repository 'PSGallery" }
        {
            # Error in Package Management
        }
        
        { $_.ToString() -match 'A second CIM class definition'}
        {
            # This happens when several versions of same module are available. 
            # Mainly a problem when when $Env:PSModulePath is polluted or 
            # DSC_Resources or DSC_Configuration are not clean 
        }
        { $_.ToString() -match ([regex]::escape("Cannot find path 'HKLM:\SOFTWARE\Microsoft\Powershell\3\DSC'")) }
        {
            if ($_.InvocationInfo.PositionMessage -match 'PSDscAllowDomainUser')
            {
                # This tend to be repeated for all nodes even if only 1 is affected
                #"  PSDscAllowDomainUser error"
            }
            else
            { # Most likely 'PSDscAllowPlainTextPassword'
                $_
            }
        }
    }
}