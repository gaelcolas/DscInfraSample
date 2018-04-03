# Demo 1

## Goal
The Goal of this demo is to show the basic layout of a control repository and that it mainly contains Data file and static scripts to generate Configuration.

It shows:
- how modules are referenced using PSDepend but excluded from Source control (we only use the artefacts),
- how the `.build.ps1` entry point starts, and the default Workflow 
- The bootstrap process and how dependencies for Build modules, Configurations and Resources are pulled from a gallery
- How the `$En:PSModulePath` is reset to avoid contamination of modules from installation path

# Steps

1. Clone the demo repo DscInfraSample locally:
```
git clone git@github.com:gaelcolas/DscInfraSample.git
```

2. Change Directory to that repo folder:
```PowerShell
cd DscInfraSample
```

3. call the .build script with the `-ResolveDependency` parameter to see the bootstrap and pulling modules into `BuildOutput\modules`.

4. look at the 