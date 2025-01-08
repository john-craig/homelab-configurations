{ config, lib, pkgs, user-environments, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ./hostModules/offsiteBackups.nix
      ./hostModules/offlineBackups.nix

      ./hostSecrets
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  environment.systemPackages = with pkgs; [
    smartmontools
    screen
    git
    dig
    cryptsetup
    clevis
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

  selfUpdater.enable = true;

  notifiedServices = {
    enable = true;

    method.gotify = {
      tokenPath = "/run/secrets/gotify/notifier/api_key";
      url = "https://gotify.chiliahedron.wtf";
    };
  };

  offsiteBackups = {
    enable = true;

    gnupgHomeDir = "/sec/gnupg/pxe_server/service/.gnupg";
    s3cmdConfigFile = "/sec/s3cmd/pxe_server/service/.s3cfg";
  };

  offlineBackups = {
    enable = true;

    backupPath = "/srv";
    mountPoint = "/mnt";

    offlineDevices = [
      "80a23603-bd5c-4a8a-9e75-074d75de7802"
      "29380df2-3ed6-40e8-a7d2-f804ce015b32"
    ];
  };

  automatedBackups = {
    enable = true;
    role = "server";

    backupHosts = {
      "homeserver1" = [
        "/srv/container"
        "/srv/documents"
      ];
    };
  };

  disasterRecovery = {
    enable = true;
    role = "server";
  };

  services.pixiecore.enable = true;

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  userProfiles.service.enable = true;

  users.users."service".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJQUkUdQE4u15DCHRcsy5RxydqXuVbOb24KxmU7N0Mkv"
  ];

  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

