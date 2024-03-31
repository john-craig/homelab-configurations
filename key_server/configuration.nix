# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  environment.systemPackages = with pkgs; [
    git
    openssl
    libfido2
    cryptsetup
    yubikey-manager4
    nano
    curl
    btrfs-progs
    python3
    # Uncomment the below if you need python3 with specific packages 
    #
    # (python3.withPackages(ps: with ps; [
    #   requests
    #   ...
    # ]))
  ];

  networking.hostName = "key-server";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      7654 # Tang
    ];
  };

  # Required for Yubikey
  services.pcscd.enable = true;

  services.tang = {
    enable = true;

    ipAddressAllow = [ "192.168.1.0/24" ];
    listenStream = [ "0.0.0.0:7654" ];
  };

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users."service" = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ/qmEMkHrkww4SsAjS+7f9qzLXJ6zDTcyzqjrgEkYN"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

