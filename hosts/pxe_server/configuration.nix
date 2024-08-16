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
    smartmontools
    screen
    git
    rsync
    s3cmd
    gnupg
    pinentry
    cryptsetup
    clevis
    python3
    ansible
  ];

  networking.hostName = "pxe-server";

  # Node Exporter
  services.prometheus.exporters = {
    node = {
      enable = true;
      port = 9100;
    };
  };

  # Required for GnuPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Offsite Backup
  systemd.timers."offsite-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Unit = "weekly-backup.service";
    };
  };

  systemd.services."offsite-backup" = {
    enable = true;
    script =
      ''
        ${pkgs.gnutar}/bin/tar -czf - /srv/backup/ | \
        ${pkgs.gnupg}/bin/gpg --encrypt --always-trust --recipient offsite-backup \
            --homedir /sec/gnupg/pxe_server/service/.gnupg | \
        ${pkgs.s3cmd}/bin/s3cmd --config=/sec/s3cmd/pxe_server/service/.s3cfg \
            --multipart-chunk-size-mb=500 \
            put - s3://chiliahedron-offsite-backups/backup.tar.gz.gpg
      '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # Daily Backup
  systemd.timers."daily-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Unit = "daily-backup.service";
    };
  };

  systemd.services."daily-backup" = {
    enable = true;
    script =
      let
        rsync_cmd = "${pkgs.rsync}/bin/rsync -ravP -e '${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -F /sec/openssh/key_server/service/.ssh/config' --rsync-path='sudo rsync'";
      in
      ''
        ${rsync_cmd} homeserver1:/srv/container/ /srv/backup/daily/homeserver1/srv/container
        ${rsync_cmd} homeserver1:/srv/documents/ /srv/backup/daily/homeserver1/srv/documents
      '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # Weekly Backup
  systemd.timers."weekly-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Unit = "weekly-backup.service";
    };
  };

  systemd.services."weekly-backup" = {
    enable = true;
    script = ''
      ${pkgs.rsync}/bin/rsync --delete -ravP /srv/backup/daily/ /srv/backup/weekly
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # Monthly Backup
  systemd.timers."monthly-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Unit = "monthly-backup.service";
    };
  };

  systemd.services."monthly-backup" = {
    enable = true;
    script = ''
      ${pkgs.rsync}/bin/rsync --delete -ravP /srv/backup/weekly/ /srv/backup/monthly
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

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

