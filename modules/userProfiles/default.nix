{ pkgs, lib, config, user-envs, ... }: {
  options = {
    userProfiles = {
      service = lib.mkOption {
        default = { };
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Service User configurations";

            authorizedKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Authorized keys to be used by this user profile";
            };
          };
        };
      };

      display = lib.mkOption {
        default = { };
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Display User configurations";

            authorizedKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Authorized keys to be used by this user profile";
            };
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    ((lib.mkIf config.userProfiles.service.enable) {
      environment.systemPackages = with pkgs; [
        zsh
      ];

      users = {
        mutableUsers = true;

        users."service" = {
          shell = pkgs.zsh;
          isNormalUser = true;
          initialPassword = null;
          extraGroups = [ "wheel" "pipewire" ];
          ignoreShellProgramCheck = true;

          openssh.authorizedKeys.keys = config.userProfiles.service.authorizedKeys;
        };
      };

      security.sudo.extraRules = [
        {
          users = [ "service" ];
          commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
        }
      ];

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users."service" = user-envs.nixosModules."service";
    })
    ((lib.mkIf config.userProfiles.display.enable) {
      environment.systemPackages = with pkgs; [
        zsh
      ];

      users = {
        mutableUsers = true;

        users."display" = {
          shell = pkgs.zsh;
          isNormalUser = true;
          initialPassword = null;
          extraGroups = [ "wheel" "pipewire" ];
          ignoreShellProgramCheck = true;

          openssh.authorizedKeys.keys = config.userProfiles.display.authorizedKeys;
        };
      };

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users."display" = user-envs.nixosModules."display";
    })
  ];
}
