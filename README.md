# DSC Repository Sample

This repository is an example of an Infrastructure, represented as code, leveraging DSC, and driven by a hierarchical data store, based on a file provider.

The approach has been heavily inspired by Chef and Puppet.

The Abstraction Layers
The Desired Infrastructure repository
The Repository Structures
The Branching Strategy

------------------------------------------------------

## The abstraction layers


The DSC Framework gives us many options to manage configurations, without much guidance or prescriptive rules to leverage them.
This repository takes an opinionated approach to Configuration Management leveraging DSC, and for this I extended the vocalubary coming from DSC to define the logical separation of concerns, for each logical components.
I especially make a distinction between the DSC Code constructs (such as `DSC Resource`, `DSC Configuration`, `DSC Composite Configuration`, `DSC Composite Resource`) and the logical roles for `Configurations` and `Resources` as I feel the code constructs are too flexible to give away a clear structure by their names.

Based on this new semantics, here's the approach to abstraction I took.

1. Role abstracts Configurations
2. Configuration abstracts resources
3. Datum abstracts Configuration Data
4. DSC Resources abstract a PowerShell Modules' functions
5. PS Modules functions abstract the underlying technology

## The Desired Infrastructure repository

An Infrastructure represented as code with DSC could look like this repository. It is inspired by Puppet's R10K, and allows to separate staging environments via git branches so that successful changes can be promoted through each environment, while keeping the infra consistent (more on this later).

The main principles this module follow are the followings:
- This is a repository that stores and organises the Infrastructure policies (Roles and Managed objects definitions. i.e. Nodes)
- Those policy documents can be seen as artifacts, versioned, and promoted through rings, excepts for Nodes which are assigned per environments.
- The Code constructs (Resource and Configurations) are not included in this repository (so they can be tested and developped individually, decoupled from the overall infra), but their specific artifacts' reference (i.e. Released module, Module Git repository in specific branch or at specific commit).

## Repository Structure

```
DSCINFRASAMPLE
│   .Build.ps1
│   .gitignore
│   LICENSE
│   PSDepend.build.psd1
│   PSDepend.configurations.psd1
│   PSDepend.resources.psd1
│   README.md
│   RootConfiguration.ps1
│
├───.build
│
├───BuildOutput
│   ├───modules
│   └───MOF
│
├───docs
│       README.md
│
├───DSC_ConfigData
│   │   Datum.yml
│   │
│   ├───AllNodes
│   │   ├───DEV
│   │   │       SRV01.yml
│   │   │
│   │   └───PROD
│   │           PRODSRV01.yml
│   │
│   ├───Environments
│   │       DEV.yml
│   │       PROD.yml
│   │
│   ├───Roles
│   │       Role1.yml
│   │
│   └───SiteData
│           KUL.yml
│           LON.yml
│
├───DSC_Configurations
└───DSC_Resources
```

## Using Branching strategies for Staging rings

I believe all changes should be tested and versioned, having tests giving you quick feedback before the change is applied, and promoting them to the next _ring_ for staged release.

In this context of Infrastructure as code, that means a code change will be tested in a Dev environment, before being promoted into Staging, to finally going to Prod (name, number of rings, and _gates_ may vary).

The best way I found to handle this workflow is leveraging branching in git, in a similar way to R10k for the puppeters.

The rough idea is to have one branch per ring: `DEV` and `PROD` here, and a different set of Nodes per environments (configData/AllNodes/`$Environment`).

By doing so, and with some _magic_ (in the Build scripts, yet to come), we build the MOFs for the Nodes based on the Branch we're working on, or we just pushed to (and allow to override this information via Build Parameters, so that anyone can test, we're just building MOFs afterall). Doing so, pushing a change to DEV would build the DEV MOFs, and those could be Pushed to the DEV Pull server (in an ideally segregated environment). When DEV tests have been successful, and it's time to release into PROD, a PR from DEV to PROD is raised (preferably automatically) and is merged in (after review, if needed).
Upon merge, the _PROD_ build task is executed, building the MOFs for the PROD environment, and deploying to the PROD Pull server.

This model should be able to handle temporary branches (with some simple logic), so that if I create a branch for testing some changes, It'll use the default environment's Nodes: DEV (also the Default branch).

PROD is a protected branch, and will not accept direct changes, everything needs to flow from DEV.

I can implement different 'Gates' between rings (like mandatory Code review by code owner for PRs going from DEV to PROD).