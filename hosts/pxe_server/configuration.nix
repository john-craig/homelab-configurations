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
    clevis
  ];

  networking.hostName = "pxe-server";
  networking.firewall.enable = false;

  garbageCollect.enable = true;

  resourceCache = {
    enable = true;

    role = "server";
    resources = {
      pacman.enable = true;
      nix.enable = true;
    };
  };

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

    s3Bucket = "s3://chiliahedron-offsite-backups";
    s3cmdConfigFile = config.sops.secrets."s3cmd/backup/s3cfg".path;

    gnupgRecipient = "offsite-backup";
    gnupgHomeDir = "/sec/gnupg/pxe_server/service/.gnupg";

    backupProfiles = [
      {
        prefix = "automated-backups";
        path = "/srv/backup";
      }
    ];
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

  userProfiles.service = {
    enable = true;
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJQUkUdQE4u15DCHRcsy5RxydqXuVbOb24KxmU7N0Mkv"
    ];
  };

  system.stateVersion = "24.05";

}

