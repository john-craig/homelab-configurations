# To build, use:
# nix-build nixos -I nixos-config=nixos/modules/installer/sd-card/sd-image-aarch64.nix -A config.system.build.sdImage
{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
  ];
  nixpkgs.crossSystem.system = "aarch64-linux";

  environment.systemPackages = with pkgs; [
    smartmontools
    git

    python3
    # Uncomment the below if you need python3 with specific packages 
    #
    # (python3.withPackages(ps: with ps; [
    #   requests
    #   ...
    # ]))
  ];

  networking.hostName = "key-server";

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users."service" = {
    isNormalUser = true;
    home = "/home/service";
    extraGroups = [ "wheel" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILKHQov74e/vYGd62Xfvm8WAwNOwUuiClRBhybl4Gv9x"
    ];
  };
}