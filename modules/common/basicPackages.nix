{ pkgs, lib, config, ... }: {
  options = {
    basicPackages.enable = lib.mkEnableOption "basic set of common packages";
  };

  config = lib.mkIf config.basicPackages.enable {
    environment.systemPackages = with pkgs; [
      rsync
    ];
  };
}
