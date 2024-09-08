{ pkgs, lib, config, ... }: {
  options = {
    notifier.enable = lib.mkEnableOption "configuration for Notifier";
  };

  config = lib.mkIf config.notifier.enable {
    environment.systemPackages = with pkgs; [
      gotify-desktop
      libnotify
    ];


  };
}
