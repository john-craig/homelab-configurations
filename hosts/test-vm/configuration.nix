{ lib, config, pkgs, ... }:
{

  services.selfhosted = {
    enable = true;
    services = [ "invidious" ];
  };

  users.users.root.initialPassword = "root";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  system.stateVersion = "23.11";
}
