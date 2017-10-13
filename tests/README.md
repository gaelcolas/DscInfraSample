# Tests for Control Repo

The control repo is where the Config Data, DSC Configurations and Resources 
are finally composed into an end to end system configuration.

As the Config Data is the key source of Information, editing should provide fast feedback.

The tests are here to fail a build when a codified policy (pester tests) are not met.
For instance, Joe User makes a change to the Config Data by Adding a Machine without a role,
the change is rejected by a corresponding pester test.

Similarly, it's now possible to ensure a naming convention is enforced. 