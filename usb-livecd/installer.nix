{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

  environment.systemPackages = with pkgs; [
    nano
    curl
    git
    python3
    rsync
    cryptsetup
    lvm2
    btrfs-progs
    clevis
  ];

  # virtualisation.docker = {
  #   enable = true;
  #   autoPrune.enable = true;
  # };

  networking.hostName = "installer";

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users = {
    mutableUsers = true;
    users."service" = {
      isNormalUser = true;
      home = "/home/service";
      initialPassword = null;
      extraGroups = [ "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdRzRSMy+IvDkl07sXJ38vbf/btGbN1gi6BT8nImzgw"
      ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  # Needed for HP utils
  nixpkgs.config.allowUnfree = true;
  hardware.raid.HPSmartArray.enable = true;

}
