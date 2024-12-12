{ pkgs, lib, config, ... }: {
  options = {
    disasterRecovery = {
      enable = lib.mkEnableOption "configuration for Caching and Disaster Recovery";

      role = lib.mkOption {
        type = lib.types.enum [ "client" "server" "both" ];
        default = "client"; # default value
        description = "Defines whether the configuration is for the client, server, or both.";
      };
    };
  };

  config = (lib.mkIf config.disasterRecovery.enable) {
    #############################################
    # Client configurations
    #############################################
    virtualisation.containers.registries = lib.mkIf
      (config.disasterRecovery.role == "client" ||
        config.disasterRecovery.role == "both")
      {
        # insecure = [ "192.168.1.5:5000" ];
        search = [ "cache.podman.chiliahedron.wtf" "lscr.io" "docker.io" ];
      };

    # Create the cacher user
    users = lib.mkIf
      (config.disasterRecovery.role == "client" ||
        config.disasterRecovery.role == "both")
      {
        groups."cacher" = { };

        users."cacher" = {
          group = "cacher";
          isNormalUser = true;
          initialPassword = null;

          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/o2EFmD7IWRI1v+0K3FdVnj4iyRGZjqbYfGYomk7jf"
          ];
        };
      };

    security.sudo.extraRules = lib.mkIf
      (config.disasterRecovery.role == "client" ||
        config.disasterRecovery.role == "both") [
      {
        users = [ "cacher" ];
        commands = [
          { command = "/run/current-system/sw/bin/podman"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    #############################################
    # Server configurations
    #############################################
    environment.systemPackages = with pkgs; lib.mkIf
      (config.disasterRecovery.role == "server" ||
        config.disasterRecovery.role == "both") [
      maturin-dr
      nix-serve-ng
    ];

    services.dockerRegistry = lib.mkIf
      (config.disasterRecovery.role == "server" ||
        config.disasterRecovery.role == "both")
      {
        enable = true;

        listenAddress = "0.0.0.0";
        port = 5000;

        storagePath = "/srv/cache/podman";

        enableDelete = true;
        enableGarbageCollect = true;
      };
  };
}
