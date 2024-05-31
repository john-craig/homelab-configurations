# Homelab Configurations
These are all the NixOS configurations for different hosts on my network. 

Currently it contains definitions for:
- bastion0
- homeserver1
- key_server
- media_kiosk
- pifarm4
- pizero2
- pxe_server

The `modules` subdirectory contains some common configuration definitions that may be pulled in by all hosts. 

Each directory for an individual host may contain a `hostModules` subdirectory containing configuration that is specific to that host.

Lastly the flake takes as input a `nixpkgs-apocrypha` which is a repository containing other packages definitions and more complex module configurations.