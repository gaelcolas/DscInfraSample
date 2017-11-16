# Configurations

The configurations are the middle layer blocks of this DSC solution: To allow a sustainable composition model,
 the Configurations are made of `DSC Composite Resources`. That's the main difference in naming between 
 the `DSC Code Constructs` provided by Microsoft and the Logical components we use.

The configuration assembles the technology driven by [the `Resources`](../DSC_Resouces/README.md) into an Interface that makes the link
 between the technology (Chocolatey) and the [Configuration Data](../DSC_ConfigData/README.md):
 - A role needs a list of package to be present for our defined state
 - to install those packages, the chocolatey sources need to be configured first
 - if we need a proxy, we need to configure it before installing packages
