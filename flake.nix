{
  description = "Home Lab Configuration Flake";

  inputs = {
    nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    nixpkgs-apocrypha.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/nixpkgs-apocrypha";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    gallipedal.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/gallipedal-module";
    gallipedal.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";
  };

  outputs = { self, nixpkgs, disko, home-manager, gallipedal, sops-nix, nixpkgs-apocrypha }@inputs:
    let
      mkNixosSystem = systemDef: (
        nixpkgs.lib.nixosSystem {
          specialArgs = { apocrypha-utils = nixpkgs-apocrypha.utilities; };
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays."${systemDef.arch}" ]; }
            gallipedal.nixosModules.gallipedal
            nixpkgs-apocrypha.nixosModules.notifiedServices
            nixpkgs-apocrypha.nixosModules.selfUpdater
            sops-nix.nixosModules.sops
            ./hosts/${systemDef.name}/configuration.nix
            ./modules
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
            home-manager.nixosModules.home-manager
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
