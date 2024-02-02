# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #./disk-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "homeserver1"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.firewall.enable = false;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  environment.systemPackages = with pkgs; [
    smartmontools
    nano
    curl
    git
    btrfs-progs
    docker
    (python3.withPackages(ps: with ps; [
      requests
      urllib3
      websocket-client
      (pkgs.python3Packages.docker.overrideAttrs(oldAttrs: rec {
         pname = "docker";
         version = "6.1.3";
         src = fetchPypi {
           inherit pname version;
           sha256 = "sha256-qm0XgwBFul7wFo1eqjTTe+6xE5SMQTr/4dWZH8EfmiA=";
         };
      }))
      (buildPythonPackage rec {
        pname = "docker-compose";
        version = "1.29.2";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-TIzZ0h0jdBJ5PRi9MxEASe6a+Nqz/iwhO70HM5WbCbc=";
        };
        doCheck = false;
        propagatedBuildInputs = [
          (pkgs.python3Packages.docker.overrideAttrs(oldAttrs: rec {
            pname = "docker";
            version = "6.1.3";
            src = fetchPypi {
              inherit pname version;
              sha256 = "sha256-qm0XgwBFul7wFo1eqjTTe+6xE5SMQTr/4dWZH8EfmiA=";
            };
          }))
          pkgs.python3Packages.python-dotenv
          pkgs.python3Packages.dockerpty
          pkgs.python3Packages.setuptools
          pkgs.python3Packages.distro
          pkgs.python3Packages.pyyaml
          pkgs.python3Packages.jsonschema
          pkgs.python3Packages.docopt
          pkgs.python3Packages.texttable
        ];
      })
    ]))
  ];

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export         192.168.1.0/24(rw,fsid=0,no_subtree_check)
    /export/media   192.168.1.0/24(rw,nohide,insecure,no_subtree_check)
  '';

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  services.apcupsd = {
    enable = true;
    configText = ''
      NISIP 0.0.0.0
      NISPORT 3551
    '';
  };

  users = {
    mutableUsers = true;
    users."evak" = {
      isNormalUser = true;
      home = "/home/evak";
      initialPassword = null;
      extraGroups = [ "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5QNL0MP8yr7OD5rt4PpnL4Go++4rdmLFhhA5ypdpLbwfXqVEKOBnjxSn4Ux0BtHk8cIK5TT9wcigx9gLKaVX2aDSROITz5DMy2EuR09/kBp8xbaAeZQgyDB0C8YHPclPBN/25krDJNocWbJTnmBSwswXYJWGMUQZxfPMUyql3jy2fcxKUg39ATz9Qe9CmJpiBVGgTva0QpNWteTHOn7zwoHDhlIYCUygR/+X9LJCv7TvDPWaeYe9Z4+q58FMt9njTFAY9mXpa2qataIjk1KwoJWs2a8/vW2kYzbdOXH8KVxZuEpqgr4HCF+qdnFbuLtUfCFRKmCr3EI/+qPtUulUggusPm4d9tkfXlLytmydX7u4wJeOwYzsbtMLOPIOmGI8Q+jQUpc9zgbd34nat8LdD+vIayjpv8fU5lziaVVvkVP6EBF4UGGo/K0cdK8GGPoODJfUrNSr5m0Rh9IFHCp5QCvYxhOn4RXtIenx+0D9Am06Ab2G8S53l8yZwuMy7NBM=" 
      ];
    };
  };

  security.sudo.extraRules = [
    { 
      users = [ "evak" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  nix.extraOptions = ''
    #tarball-ttl = 0
  '';

  # Do not change
  system.stateVersion = "24.05";
}

