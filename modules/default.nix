{ pkgs, lib, ... }: {
  imports = [
    ./common/basicPackages.nix
  ];

  basicPackages.enable = lib.mkDefault false;
}
