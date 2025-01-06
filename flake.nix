{
  description = "Home Lab Configuration Flake";

  inputs = {
    nixpkgs-apocrypha.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/nixpkgs-apocrypha";

    gallipedal.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/gallipedal-module";
    gallipedal.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    user-environments.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/user-environment-configurations";
    user-environments.inputs.nixpkgs-apocrypha.follows = "nixpkgs-apocrypha";

    nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";
    home-manager.follows = "user-environments/home-manager";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";
  };

  outputs = { self, nixpkgs, disko, home-manager, gallipedal, user-environments, sops-nix, nixpkgs-apocrypha }@inputs:
    let
      mkNixosSystem = systemDef: (
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            hostname = systemDef.name;
            apocrypha-utils = nixpkgs-apocrypha.utilities;
            user-environments = user-environments;
          };
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays."${systemDef.arch}" ]; }
            gallipedal.nixosModules.gallipedal
            home-manager.nixosModules.home-manager
            nixpkgs-apocrypha.nixosModules.notifiedServices
            nixpkgs-apocrypha.nixosModules.selfUpdater
            sops-nix.nixosModules.sops
            ./hosts/${systemDef.name}/configuration.nix
            ./modules
            ./secrets
          ] ++ nixpkgs.lib.lists.optionals
            (builtins.hasAttr "extraModules" systemDef)
            systemDef.extraModules;
        }
      );
    in
    {

      nixosConfigurations = {
        homeserver1 = mkNixosSystem {
          name = "homeserver1";
          arch = "x86_64-linux";
          extraModules = [
            nixpkgs-apocrypha.nixosModules.smartctl-ssacli-exporter
          ];
        };

        media_kiosk = mkNixosSystem {
          name = "media_kiosk";
          arch = "x86_64-linux";
          extraModules = [
            disko.nixosModules.disko
          ];
        };

        key_server = mkNixosSystem {
          name = "key_server";
          arch = "aarch64-linux";
          extraModules = [ ];
        };

        pxe_server = mkNixosSystem {
          name = "pxe_server";
          arch = "aarch64-linux";
          extraModules = [ ];
        };

        bastion0 = mkNixosSystem {
          name = "bastion0";
          arch = "x86_64-linux";
          extraModules = [ ];
        };
      };

    };
}
