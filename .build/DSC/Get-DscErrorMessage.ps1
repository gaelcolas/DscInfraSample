function Get-DscErrorMessage
{
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    switch ($Exception)
    {
        { $_.ToString() -match "Unable to find repository 'PSGallery" }
        {
            'Error in Package Management'
        }
        
        { $_.ToString() -match 'A second CIM class definition'}
        {
            # This happens when several versions of same module are available. 
            # Mainly a problem when when $Env:PSModulePath is polluted or 
            # DSC_Resources or DSC_Configuration are not clean
            'A second CIM class definition exists, maybe a module exists twice and no explicit module version is specified'
        }
        { $_.ToString() -match ([regex]::Escape("Cannot find path 'HKLM:\SOFTWARE\Microsoft\Powershell\3\DSC'")) }
        {
            if ($_.InvocationInfo.PositionMessage -match 'PSDscAllowDomainUser')
            {
                # This tend to be repeated for all nodes even if only 1 is affected
                'Credentials are used and PSDscAllowDomainUser is not set'
            }
            else
            {
                'Plain text passwords are used and PSDscAllowPlainTextPassword is not set'
            }
        }
    }
}