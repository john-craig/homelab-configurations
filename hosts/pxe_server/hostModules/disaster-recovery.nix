{ pkgs, lib, config, ... }: {
  options = {
    disaster-recovery.enable = lib.mkEnableOption "Disaster Recovery services";
  };

  config = lib.mkIf config.backups.enable {
    services.dockerRegistry = {
      enable = true;

      listenAddress = "0.0.0.0";
      port = 5000;

      storagePath = "/srv/cache/container";
    };
  };
}