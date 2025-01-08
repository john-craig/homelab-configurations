{ pkgs, lib, config, user-envs, ... }: {
  options = {
    userProfiles = {
      service = lib.mkOption {
        default = { };
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Service User configurations";
          };
        };
      };

      display = lib.mkOption {
        default = { };
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Display User configurations";
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    ((lib.mkIf config.userProfiles.service.enable) {
      programs.zsh.enable = true;
      users = {
        mutableUsers = true;

        users."service" = {
          shell = pkgs.zsh;
          isNormalUser = true;
          initialPassword = null;
          extraGroups = [ "wheel" "pipewire" ];
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
      home-manager.users."service" = user-envs.nixosModules."service@generic";
    })
    ((lib.mkIf config.userProfiles.display.enable) {
      programs.zsh.enable = true;
      users = {
        mutableUsers = true;

        users."display" = {
          shell = pkgs.zsh;
          isNormalUser = true;
          initialPassword = null;
          extraGroups = [ "wheel" "pipewire" ];
        };
      };

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users."display" = user-envs.nixosModules."display@generic";
    })
  ];
}
