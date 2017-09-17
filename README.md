# DSC Repository Sample

This repository is an example of an implementation of DSC driven by a hierarchical configuration data store.

## The abstraction layers

The DSC Framework gives us many options to manage configurations, without much guidance or prescriptive rules to leverage them.
This repository takes an opinionated approach to Configuration Management leveraging DSC, and for this I extended the vocalubary coming from DSC to define the logical segragation of concerns, for each logical components.
I especially make a distinction between the DSC Code constructs (such as `DSC Resource`, `DSC Configuration`, `DSC Composite Configuration`, `DSC Composite Resource`) and the logical roles for `Configurations` and `Resources` as I feel the code constructs are too flexible to give away a clear structure by their names.

Based on this new semantics, here's the approach to abstraction I took.

1. Role abstracts Configurations
2. Configuration abstracts resources
3. Datum abstracts Configuration Data
4. DSC Resources abstract a PowerShell Modules' functions
5. PS Modules functions abstract the underlying technology


## Repository Structure

```
DSCINFRASAMPLE
│   .Build.ps1
│   Configurations.psd1
│   Datum.yml
│   Dependencies.psd1
│   README.md
│   Resources.psd1
│
├───.build
├───ConfigData
│   ├───AllNodes
│   │   └───DEV
│   │           SRV01.yml
│   │
│   ├───Environments
│   │       DEV.yml
│   │
│   ├───Roles
│   │       Role1.yml
│   │
│   └───SiteData
│           LON.yml
│
├───Configurations
│       README.md
│
├───DscBuildOutput
│       README.md
│
└───Resources
        README.md
```