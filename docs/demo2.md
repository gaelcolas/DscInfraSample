# Demo 2

## Goal

The Goal to this demo is to show the basic behaviour of Datum, and how to interact with it.

## Steps

After Loading the Configuration Data, show the content of the $Datum object.
```PowerShell
$Datum
```

Show how:
- it relates to the `DSC_ConfigData` folder.
- the Definition represents the `Datum.yml`
- how `$Datum.AllNodes.DEV.SRV01` returns an object, grabs the data from the file, and returns an OrderedDictionary.

```PowerShell
$Datum.AllNodes.DEV.SRV01
$VerbosePreference = 'Continue'
$Datum.AllNodes.DEV.SRV01
$VerbosePreference = 'SilentlyContinue'

```

Show that editing the file is directly seen in the object.