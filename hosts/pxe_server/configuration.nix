# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ./hostModules/backups.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  environment.systemPackages = with pkgs; [
    smartmontools
    screen
    git
    cryptsetup
    clevis
    python3
  ];

  networking.hostName = "pxe-server";
  networking.firewall.enable = false;

  # Node Exporter
  services.prometheus.exporters = {
    node = {
      enable = true;
      port = 9100;
    };

    systemd = {
      enable = true;
      port = 9558;
    };
  };

  backups.enable = true;

  services.pixiecore.enable = true;

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users."service" = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJQUkUdQE4u15DCHRcsy5RxydqXuVbOb24KxmU7N0Mkv"
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

