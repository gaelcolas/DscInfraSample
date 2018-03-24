# DSC Repository Sample

This repository is an example of an Infrastructure, represented as code, leveraging DSC, and driven by a hierarchical data store, based on a file provider.

The approach has been heavily inspired by Chef and Puppet.

1. [Getting Started](#getting-started)
2. [The Abstraction Layers](#the-abstraction-layers)
3. [The Desired Infrastructure repository](#the-desired-infrastructure-repository)
4. [The Repository Structures](#repository-structure)
5. [The Release Strategy](#the-release-strategy)


------------------------------------------------------
## Getting Started

If you learn by doing, here's how to get started quickly.
In this repository, you should have all you need to get started.
The requirements (on the top of my head) are the following:
- git
- WMF 5.1 (that should include PowerShellGet v1.0.0.1 at least, enough to bootstrap to latter versions)

Here's a demo of the process described below:
[![Building DscInfraSample](https://user-images.githubusercontent.com/8962101/37863798-1dff8560-2f5c-11e8-85eb-06109fa46a82.png)](https://videopress.com/embed/AOUCnVF9)

### Git Clone

First, clone the repository using either ssh or https:
```
git clone git@github.com:gaelcolas/DscInfraSample.git
```
or
```
git clone https://github.com/gaelcolas/DscInfraSample.git
```

### Bootstrap and save module dependencies

As this build script is meant to be runnable both from your development machine and from an ephemeral build agent, the script should be able to bootstrap itself, as long as it can download from a PowerShell Gallery, whether Internal or [the PSGallery](https://www.powershellgallery.com/).
This version of DscInfraSample is still in development, and for this reason it also downloads dependencies from github. You can pull them instead into your internal repository, and update the [PSDepend](https://github.com/RamblingCookieMonster/PSDepend) files to target those versions instead. 

#### How you execute this:

```PowerShell
C:\ > .build.ps1 -resolveDependency
```

#### What does that do?

- Set the TLS Setting of the session to Tls12 for Github
- Install PSDepend from the Gallery to user scope (I will change that to save to `BuildOutput\Modules`)
- Execute PSDepend with the Dependency file `PSDepend.build.ps1` (that will save all modules listed in `BuildOutput\Modules\`)
- Update the $Env:PSModulePath for the session
- Hand-over to [Invoke-Build](https://github.com/nightroman/Invoke-Build) 
- Import all tasks and functions from the `.build/` folder
- Start the execution of the default task defined in the `.build.ps1` script (task '.')

The reason the resolve Dependency is a parameter is that you don't need to run it every time. You usually run it the first time after cloning/pulling the repository.
When you only make some changes to data, you probably don't need to, unless you change one of the PSDepend file / add a new dependency.

### Default Task sequence

Once the bootstrap process is finished, and the required modules for the build process are available, the processing is handled by the default Invoke-Build task '.'

It is defined like this in the `.build.ps1` file, and you can customize it to suite your workflow.

```
    task . Clean,
            PSModulePath_BuildModules,
            test,
            LoadResource,
            LoadConfigurations,
            CompileDSCWithDatum,
            PackageModuleForPull
```
This version starts by cleaning the BuildOutput folder from previous artifacts while leaving the required modules (It removes MOFs, Meta MOFs, Packaged Modules).

It changes the PSModulePath so that the DSC compilation can find the modules required in 
- `BuildOutput\modules`
- `DSC_Configurations`
- `DSC_Resources`

The test tasks is a simple example of a Task added to the workflow, defined in .build.ps1:
```PowerShell
    task test {
        Write-Host (Get-Module Datum,DscBuildHelpers,Pester,PSSscriptAnalyser,PSDeploy -ListAvailable | FT -a | Out-String) 
    }
```

**LoadResource** invoke PSDepend to download the dependencies defined in PSDepend.resources.psd1.

**LoadConfigurations** does the same for PSDepend.configurations.psd1.

**CompileDSCWithDatum** calls 3 subtasks:
- LoadDatumConfigData
- CompileRootConfiguration
- CompileRootMetaMof
- CreateChecksums

> this is defined in the [ConfigData.build.ps1](./.build/DSC/ConfigData.build.ps1) task file

**LoadDatumConfigData** will create the required hashtable used by DSC with two keys:
- they key `AllNodes` containing an array of hashtable defining the nodes
- a `NonNodeData` key called `Datum`, where it stores the Datum object

This hashtable is saved in the `$Global:ConfigurationData` variable for ease of retrieval.
It also creates the `$Global:Datum` variable, convenient during development.

**CompileRootConfiguration** will execute the [`RootConfiguration.ps1`](./RootConfiguration.ps1) file, which is what triggers the actual MOF compilation process.

This is where you should define the Configurations (or their module) to be used by DSC.
e.g.
```PowerShell
Import-DscResource -ModuleName SharedDscConfig -ModuleVersion 0.0.4
```
Unfortunately, I haven't found an (easy) way to do this dynamically yet.

Then the Configuration will iterate through the Nodes, and resolve the configuration data dynamically :
```PowerShell
    node $ConfigurationData.AllNodes.NodeName {
        $(Write-Warning "Processing Node $($Node.Name) : $($Node.nodeName)")
        (Lookup 'Configurations').Foreach{
            $ConfigurationName = $_
            $(Write-Warning "`tLooking up params for $ConfigurationName")
            $Properties = $(lookup $ConfigurationName -DefaultValue @{})
            Get-DscSplattedResource -ResourceName $ConfigurationName -ExecutionName $ConfigurationName -Properties $Properties
        }
    }
```
The 'Configurations' key defines what Configuration (DSC Composite Resource) should be 'executed' during compile time for a given Node, and it resolves the Properties to be used (and [splat them to the Composite resource](https://gaelcolas.com/2017/11/05/pseudo-splatting-dsc-resources/)).

**CompileRootMetaMof** will do something very similar but for the Meta MOFs, running the `RootMetaMOF.ps1` configuration.
Because of the way the LCM config are generated, this one is less dynamic, but do not need to change anyway.

_____

## The abstraction layers


The DSC Framework gives us many options to manage configurations, without much guidance or prescriptive rules to leverage them.
This repository takes an **opinionated** approach to Configuration Management leveraging **DSC**, and for this I _extended_ (or adapted) the vocalubary coming from DSC to define the logical separation of concerns, for each component.
I especially make a distinction between the **DSC Code constructs** (such as `DSC Resource`, `DSC Configuration`, `DSC Composite Configuration`, `DSC Composite Resource`) and the **logical roles** they play such as `Configurations` and `Resources` as I feel the code constructs are too flexible to give away a clear structure by their names.

Based on this new semantics, here's the approach to abstraction I took.

1. [Role](./DSC_ConfigData/README.md) abstracts [Configurations](./DSC_Configurations/README.md)
2. Configurations abstracts resources
3. Datum compose Node Configuration Data
4. DSC Resources abstract a PowerShell Modules' functions
5. PS Modules functions abstract the underlying technology

## The Desired Infrastructure repository

An Infrastructure represented as code with DSC could look like this repository. It is inspired by Puppet's R10K and Hiera, and allows to separate staging environments via git branches so that successful changes can be promoted through each environment, while keeping the infra consistent (more on this later).

The main principles this module follow are the followings:
- This is a repository that stores and organises the Infrastructure policies (Roles and Managed objects definitions. i.e. Nodes)
- Those policy documents can be seen as artifacts, versioned, and promoted through rings, excepts for Nodes which are assigned per environments.
- The Code constructs (Resource and Configurations) are not included in this repository (so they can be tested and developped individually, decoupled from the overall infra), but their specific artifacts' reference (i.e. Released module, Module Git repository in specific branch or at specific commit).

## Repository Structure

### Fresh from a git clone
```
DSCINFRASAMPLE
│   .Build.ps1
│   .gitignore
│   LICENSE
│   PSDepend.build.psd1│   PSDepend.configurations.psd1
│   PSDepend.resources.psd1
│   PSDeploy.deployall.ps1
│   README.md
│   RootConfiguration.ps1
│   RootMetaMOF.ps1
│
├───.build
│   ├───BuildHelpers
│   │       clean.build.ps1
│   └───DSC
│           ConfigData.build.ps1
├───DSC_ConfigData
│   │   Datum.yml
│   │   README.md
│   │
│   ├───AllNodes
│   │   ├───DEV
│   │   │       SRV01.yml
│   │   │       SRV02.yml
│   │   │
│   │   └───PROD
│   │           PRODSRV01.yml
│   │
│   ├───Environments
│   │       DEV.yml
│   │       PROD.yml
│   │
│   ├───Roles
│   │   │   All.yml
│   │   │   Role1.yml
│   │   │   WindowsBase.yml
│   │   │
│   │   └───Role2
│   │           Subkey1.yml
│   │           Subkey2.json
│   │
│   └───SiteData
│           KUL.yml
│           LON.yml
│
├───DSC_Configurations
├───DSC_Resources
└───tests
        README.md
```
### After `-ResolveDependency`
```
DSCINFRASAMPLE
│   .Build.ps1
│   .gitignore
│   LICENSE
│   PSDepend.build.psd1│   PSDepend.configurations.psd1
│   PSDepend.resources.psd1
│   PSDeploy.deployall.ps1
│   README.md
│   RootConfiguration.ps1
│   RootMetaMOF.ps1
│
├───.build
│   ├───BuildHelpers
│   │       clean.build.ps1
│   └───DSC
│           ConfigData.build.ps1
│
├───BuildOutput
│   ├───DscModules
│   │       chocolatey_0.0.48.zip
│   │       chocolatey_0.0.48.zip.checksum
│   │
│   ├───MetaMof
│   │       9d8cc603-5c6f-4f6d-a54a-466a6180b589.meta.mof
│   │       SRV02.meta.mof
│   │
│   ├───modules
│   │   ├───BuildHelpers
│   │   ├───datum
│   │   ├───DscBuildHelpers
│   │   ├───InvokeBuild
│   │   ├───Pester
│   │   ├───powershell-yaml
│   │   ├───PSDeploy
│   │   └───PSScriptAnalyzer
│   └───MOF
│           9d8cc603-5c6f-4f6d-a54a-466a6180b589.mof
│           9d8cc603-5c6f-4f6d-a54a-466a6180b589.mof.checksum
│           SRV02.mof
│           SRV02.mof.checksum
├───DSC_ConfigData
│   │   Datum.yml
│   │   README.md
│   │
│   ├───AllNodes
│   │   ├───DEV
│   │   │       SRV01.yml
│   │   │       SRV02.yml
│   │   │
│   │   └───PROD
│   │           PRODSRV01.yml
│   │
│   ├───Environments
│   │       DEV.yml
│   │       PROD.yml
│   │
│   ├───Roles
│   │   │   All.yml
│   │   │   Role1.yml
│   │   │   WindowsBase.yml
│   │   │
│   │   └───Role2
│   │           Subkey1.yml
│   │           Subkey2.json
│   │
│   └───SiteData
│           KUL.yml
│           LON.yml
│
├───DSC_Configurations
│   │   README.md
│   │
│   └───sharedDscConfig
│       │   SharedDscConfig.psd1
│       │
│       └───DscResources
│           ├───Shared1
│           │       Shared1.psd1
│           │       Shared1.schema.psm1
│           │   
│           └───SoftwareBase
│                   SoftwareBase.psd1
│                   SoftwareBase.schema.psm1
│
├───DSC_Resources
│   │   README.md
│   └───chocolatey
│       └───0.0.48
│           │   Chocolatey.psd1
│           │   Chocolatey.psm1
│           │
│           ├───DscResources
│           │   ├───ChocolateyFeature
│           │   ├───ChocolateyPackage
│           │   ├───ChocolateySetting
│           │   ├───ChocolateySoftware
│           │   └───ChocolateySource
│          ...
└───tests
        README.md

```

## The Release Strategy