function Get-FilteredConfigurationData {
    Param(
        $Environment = 'DEV',

        [String]
        $Role = '',

        [AllowNull()]
        $FilterNode,

        $Datum = $(Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    $AllNodes = @($Datum.AllNodes.($Environment).PSObject.Properties.Foreach{
        $Node = $Datum.AllNodes.($Environment).($_.Name)
        $Node['Environment'] = $Environment
        if(!$Node.contains('Name')) {
            $Null = $Node.Add('Name',$_.Name)
        }
        if($Role -eq ''){
            (@{} + $Node)
        }
        elseif($Node.Role -eq $Role){
            (@{} + $Node)
        }
        
    })

    if($FilterNode) {
        $AllNodes = $AllNodes.Where{$_.Name -in $FilterNode}
    }

    return @{
        AllNodes = $AllNodes
        Datum = $Datum
    }
}