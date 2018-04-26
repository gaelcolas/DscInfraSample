function Get-FilteredConfigurationData {
    Param(
        $Environment = 'DEV',

        [ScriptBlock]
        $Filter = {},

        $Datum = $(Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    $AllNodes = @($Datum.AllNodes.($Environment).PSObject.Properties.Foreach{
        $Node = $Datum.AllNodes.($Environment).($_.Name)
        $Node['Environment'] = $Environment
        if(!$Node.contains('Name')) {
            $Null = $Node.Add('Name',$_.Name)
        }
        (@{} + $Node)
    })

    if($Filter.ToString() -ne ([System.Management.Automation.ScriptBlock]::Create({})).ToString()){
        $AllNodes = [System.Collections.Hashtable[]]$AllNodes.Where($Filter)
    }

    return @{
        AllNodes = $AllNodes
        Datum = $Datum
    }
}