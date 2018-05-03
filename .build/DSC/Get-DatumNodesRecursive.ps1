function Get-DatumNodesRecursive
{
    param(
        [object[]]$Nodes,

        [int]$Depth
    )
    if ($Depth -gt 0)
    {
        $expandedNodes = foreach ($node in $Nodes)
        {
            foreach ($propertyName in ($node.PSObject.Properties | Where-Object MemberType -eq 'ScriptProperty').Name)
            {
                $node | ForEach-Object {
                    $newNode = $_."$propertyName"
                    if ($newNode -is [System.Collections.IDictionary]) {
                        if (!$newNode.Contains('Name')) {
                            $newNode.Add('Name', $propertyName)
                        }
                        
                        [hashtable]$newNode
                    }
                    else
                    {
                        $newNode
                    }
                }
            }
        }
        
        if ($expandedNodes)
        {
            $expandedNodes = FlattenArray -InputObject $expandedNodes
            $Depth--
            $expandedNodes | Where-Object { $_ -is [System.Collections.IDictionary] }
            Get-DatumNodesRecursive -Nodes $expandedNodes -Depth $Depth
        }
        else
        {
            #$Nodes
            $Depth = 0
        }
    }
    else
    {
        #$Nodes
    }
}