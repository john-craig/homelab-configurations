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
    yubikey-manager
    gnupg
    pinentry
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

  # Required for Yubikey and GnuPG
  services.pcscd.enable = true;

  systemd.services."cryptsetup@" = {
    onFailure = [
      # TODO: add some kind of notifier here
    ];
  };

  services.tang = {
    enable = true;

    ipAddressAllow = [ "192.168.1.0/24" ];
    listenStream = [ "0.0.0.0:7654" ];
  };

  # Ensure that the tang server doesn't work if the bind mount
  # for /var/lib/private isn't there
  systemd.sockets.tangd = {
    after = [
      "var-lib-private-tang.mount"
    ];
    requires = [
      "var-lib-private-tang.mount"
    ];
  };

  # SSH Key Backups
  systemd.timers."ssh-key-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Unit = "ssh-key-backup.service";
    };
  };

  systemd.services."ssh-key-backup" = {
    enable = true;
    script =
      let
        rsync_cmd = "${pkgs.rsync}/bin/rsync -ravP -e '${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -F /sec/openssh/key_server/service/.ssh/config'";
      in
      ''
        ${rsync_cmd} galahad_workstation:/sec/openssh/galahad/.ssh/ /sec/openssh/workstation/galahad/.ssh || true
        ${rsync_cmd} evak_laptop:/home/evak/.ssh/ /sec/openssh/laptop/evak/.ssh || true
      '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };


  # Cryptsetup backups
  systemd.timers."cryptsetup-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Unit = "cryptsetup-backup.service";
    };
  };

  systemd.services."cryptsetup-backup" = {
    enable = true;
    script =
      let
        rsync_cmdA = "${pkgs.rsync}/bin/rsync -ravP -e '${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -F /sec/openssh/key_server/service/.ssh/config'";
        rsync_cmdB = "${pkgs.rsync}/bin/rsync -ravP -e '${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -F /sec/openssh/key_server/service/.ssh/config' --rsync-path='sudo rsync'";
      in
      ''
        ${rsync_cmdA} sec_backup_workstation:/root/cryptsetup/ /sec/cryptsetup/workstation || true
        ${rsync_cmdB} homeserver1:/root/cryptsetup/ /sec/cryptsetup/homeserver1 || true
        ${rsync_cmdB} pxe_server:/root/cryptsetup/ /sec/cryptsetup/pxe_server || true
      '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
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

