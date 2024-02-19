# To build, use:
# nix-build nixos -I nixos-config=nixos/modules/installer/sd-card/sd-image-aarch64.nix -A config.system.build.sdImage
{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
  ];
  nixpkgs.crossSystem.system = "aarch64-linux";

  environment.systemPackages = [
    pkgs.smartmontools
  ];

  pifarmHosts = {
    "DC:A6:32:8F:2F:B8" = pifarm1;
    "DC:A6:32:10:4D:EC" = pifarm2;
    "E4:5F:01:0E:69:79" = pifarm3;
    "D8:3A:DD:2D:7E:AC" = pifarm4;
  };

  networking.hostName =
    if builtins.hasAttr "end0" networking.interfaces
    then builtins.getAttr networking.interfaces."end0".macAddress pifarmHosts or ""
    else "";

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users."gardener" = {
    isNormalUser = true;
    home = "/home/gardener";
    extraGroups = [ "wheel" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILKHQov74e/vYGd62Xfvm8WAwNOwUuiClRBhybl4Gv9x"
    ];
  };
}
