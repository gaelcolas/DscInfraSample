# Configuration Data

This is the key to making DSC scalable and secure while raising cattle and not pets.

Using the [Datum](https://github.com/gaelcolas/Datum) module, we create a hierarchical data store
that contains generic values (i.e. in roles), and specific overrides per layer in an order of precedence
that makes sense to your context.
A common scenario, is that of a **role** defining a global settings for an IIS application, 
but with specifc being overriden either per **location**, **environment**, or for a specific **node**.

Datum exposes a lookup function that accepts the current `$Node` data (when iterating through `AllNodes` of a `$configurationData`),
the `Property Path` of the value in the hierarchical data store, and a default value to use 
if no value is found in the hierarchical data store.

```PowerShell
Lookup $Node 'Base1\Property1'
```
This would do a lookup through the hierarchy as defined in the [Datum definition file](./Datum.yml),
following the order of precedence defined under the **Resolution precedence key**.

```yaml
ResolutionPrecedence:
  - 'AllNodes\$($Node.Name)'
  - 'AllNodes\<%= $CurrentNode.PSObject.Properties.where{$_.Name -eq $Node.Name}.Value%>\Roles' #script block execution
  - 'AllNodes\All\Roles'
  - 'SiteData\$($Node.Location)'
  - 'SiteData\$($Node.Location)\Roles' #variable expansion
  - 'SiteData\All'
  - 'SiteData\All\Roles'
  - 'Roles'
  - 'Roles\$($Node.Role)' #if Node has unique role, otherwise use <%= $CurrentNode.PSObject.Properties.where{$_.Name -in $Node.Role}.Value %>
  - 'Roles\All'
```

The Lookup also supports different merge behaviour (currently 2, and soon a few more), but the default
is to return the most specific data, that is the one defined the closer to the top of our layers of precedences.

In this case, it would start the lookup by looking in the path:
`"AllNodes\$($Node.Name)\Base1\Property1"`
If no value is found there, it'll try the next layer:
`"AllNodes\<%= $CurrentNode.PSObject.Properties.where{$_.Name -eq $Node.Name}.Value%>\Roles\Base1\Property1"`

> As a side note, those two example show variable substitution/expansion `$()` and
> script execution `<%= %>`. The latter could have been written more simply with `$($Node.Name)`.

It would then continue for each of the layer defined until something (`!$null`) is returned,
or at the end, if specified return the Default value.

When the property path is evaluated, Datum is walking through the objects so that it translates like:
`$ConfigurationData.Datum.AllNodes.($Node.Name).Base1.Property1`.

This abstracts away the method and technology used to store the actual data:
```Yaml
DatumStructure:
  - StoreName: AllNodes
    StoreProvider: Datum::File
    StoreOptions:
      DataDir: "./AllNodes"
 
  - StoreName: SiteData
    StoreProvider: Datum::File
    StoreOptions:
      DataDir: "./SiteData"

  - StoreName: Environments
    StoreProvider: Datum::File
    StoreOptions:
      DataDir: "./Environments"

  - StoreName: Roles
    StoreProvider: Datum::File
    StoreOptions:
      DataDir: "./Roles"
```

This structure above show the way the `$Datum` object is constructed, by mounting 'Store' to it,
in this case using the built-in File provider, that loads json, yml, psd1 files into hashtables.

You can look at the [RootMetaMOF.ps1](../RootMetaMOF.ps1) to see how the Lookup is used to generate Meta MOFs,
and [All.yml](./Roles/All.yml) to see what data is returned (no override in this case, it's directly the last layer).

In comparison, the [RootConfiguration.ps1](../RootConfiguration.ps1) has this block:
```PowerShell
    (Lookup $Node 'Configurations') | % {
        $ConfigurationName = $_
        $(Write-Warning "Looking up params for $ConfigurationName")
        $Properties = $(lookup $Node $ConfigurationName -Verbose -DefaultValue @{})
        #x $ConfigurationName $ConfigurationName $Properties
        Get-DscSplattedResource -ResourceName $ConfigurationName -ExecutionName $ConfigurationName -Properties $Properties
    }
```
> Side note, this the principle used by Puppet's Hiera and Roles & Profiles approach, great source of inspiration (and documentation)!

It is looking for the `Configurations` keys' values, and iterate through them.
For each of those Configuration Name, it looks up for values defined with the Configuration Name as key,
and finally 'splat' the DSC resource with the retrieved parameters.
So for data looking like:
```Yaml
Configuration:
  - Test
Test:
  Param1: Value1
  Param2: Value2
```

It calls the DSC:

```PowerShell
Test Test {
    Param1 = 'Value1'
    Param2 = 'Value2'
}
```

Note that this method does not yet handle 'execution names' from config Data (so calling Test twice would not be supported).
Suggestions welcome, but I haven't encountered the need yet, as Configurations tends to have a unique instance per role. 