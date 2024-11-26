{ pkgs, lib, config, ... }: {
  options = {
    disasterRecovery = {
      enable = lib.mkEnableOption "configuration for Caching and Disaster Recovery";

      role =
        let
          # Define the allowed values as a list
          allowedValues = [ "client" "server" "both" ];
        in
        lib.mkOption {
          type = lib.types.str;
          default = "client"; # default value
          description = "Defines whether the configuration is for the client, server, or both.";
        };
    };
  };

  config = lib.mkIf
    (config.disasterRecovery.enable &&
      (config.disasterRecovery.role == "client" ||
        config.disasterRecovery.role == "both"))
    {
      # Client configuration

      virtualisation.containers.registries = {
        # insecure = [ "192.168.1.5:5000" ];
        search = [ "cache.podman.chiliahedron.wtf" "lscr.io" "docker.io" ];
      };

      # Create the cacher user
      users = {
        users."cacher" = {
          isSystemUser = true;
          initialPassword = null;

          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/o2EFmD7IWRI1v+0K3FdVnj4iyRGZjqbYfGYomk7jf"
          ];
        };
      };

      security.sudo.extraRules = [
        {
          users = [ "cacher" ];
          commands = [
            { command = "${pkgs.podman}/bin/podman image ls*"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.podman}/bin/podman push*"; options = [ "NOPASSWD" ]; }
          ];
        }
      ];

    } // lib.mkIf
    (config.disasterRecovery.enable &&
      (config.disasterRecovery.role == "server" ||
        config.disasterRecovery.role == "both"))
    {
      # Server configuration
      environment.systemPackages = with pkgs; [
        atlas
        nix-serve-ng
      ];

      services.dockerRegistry = {
        enable = true;

        listenAddress = "0.0.0.0";
        port = 5000;

        storagePath = "/srv/cache/podman";

        enableDelete = true;
        enableGarbageCollect = true;
      };
    };
}
