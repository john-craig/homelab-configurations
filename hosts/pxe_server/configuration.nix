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
    git
    rsync
    cryptsetup
    clevis
    python3
    # Uncomment the below if you need python3 with specific packages 
    #
    # (python3.withPackages(ps: with ps; [
    #   requests
    #   ...
    # ]))
    ansible
  ];

  networking.hostName = "pxe-server";

  # Ansible hosts
  environment.etc = {
    "ansible/hosts".text = ''
      all:
        vars:
          ansible_ssh_extra_args: -F /sec/service/.ssh/config

      ungrouped:
        hosts:
          media_kiosk:
          homeserver1:
          pxe_server:
    '';
  };

  # Backup script
  services.cron =
    let
      backupScript = pkgs.writeScriptBin "backupScript" ''
        #!${pkgs.bash}/bin/bash

        [[ -f /var/run/backupScript.pid ]] && exit
        echo $$ > /var/run/backupScript.pid

        git clone -n https://gitea.chiliahedron.wtf/john-craig/homelab-backup-playbook.git --depth 1 /tmp/backup-playbook
        pushd /tmp/backup-playbook
          git checkout HEAD main.yaml

          ansible-playbook main.yaml
        popd

        rm -rf /tmp/backup-playbook
        rm /var/run/backupScript.pid
      '';
    in
    {
      enable = true;
      systemCronJobs = [
        "0 0 * * *     root    ${backupScript}/bin/backupScript > /var/log/backup-script.log"
      ];
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

