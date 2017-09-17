# Configurations

The configurations are the Building blocks of this DSC solution: To allow a sustainable composition model, the Configurations are made of `DSC Composite Resources`. That's the main difference in naming between the `DSC Code Constructs` provided by Microsoft and the Logical components we use.

By composing the configuration in Roles, we create unique high level templates we can apply to any number of nodes, defining generic configuration (to raise cattles).
At the same time, the hierarchical data store (Datum) allow us to have overrides and to define the specific data required to handle some configurations (i.e. Name to join computer to a domain, VM ID for Asset lifecycle, Thumbprint for Node-specific certificate...).

To make the configuration easier to read to the admins of the system, we limit the Nodes to have One role at most, so that most data can be found under the Role definition.