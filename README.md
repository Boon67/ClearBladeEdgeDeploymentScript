# ClearBladeEdgeDeploymentScript
Interactive Deployment Script to Deploy the ClearBlade Edge Binaries on a Linux system using systemd
Runs through the typical processes for deploying a ClearBlade Edge, using systemd for running it as a service.

### Requires the following items to be entered:
*Edge Cookie:* Identifier to the system as the unique edge

*Edge Name/ID:* Name of the edge to be deployed

*Parent System:* Parent System Identifier

*Platform FQDN:* Hostname for the Platform. Can be an IP address. Do not include http or https (i.e. server.host.com)

### Execution Details
Needs to be Run with root or sudo privileges
Checks for previous installed versions
Enables DB on Edge

###### Status Checks
Installs a service named "clearblade.service"
Because the script installs the edge as systemd, it can be monitors by systemctl or journalctl commands.

#### Binary Locations
/usr/bin/clearblade/edge

#### DB Location
/usr/bin/clearblade

#Note: Currently does not support auto install of OSX edges (coming soon)
