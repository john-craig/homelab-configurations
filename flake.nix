{
  description = "Home Lab Configuration Flake";

  inputs = {
    nixpkgs.follows = "nixpkgs-apocrypha/nixpkgs";

    nixpkgs-apocrypha.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/nixpkgs-apocrypha";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    gallipedal.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/gallipedal-module";
    gallipedal.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, home-manager, gallipedal, nixpkgs-apocrypha }@inputs: {

    nixosConfigurations = {
      homeserver1 =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays."x86_64-linux" ]; }
            gallipedal.nixosModules.gallipedal
            nixpkgs-apocrypha.nixosModules.smartctl-ssacli-exporter
            nixpkgs-apocrypha.nixosModules.selfUpdater
            ./hosts/homeserver1/configuration.nix
            ./modules
          ];
        };

      media_kiosk =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays."x86_64-linux" ]; }
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            gallipedal.nixosModules.gallipedal
            ./hosts/media_kiosk/configuration.nix
            ./modules
          ];
        };

      key_server = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/key_server/configuration.nix
          ./modules
        ];
      };

      pxe_server = nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays."aarch64-linux" ]; }
          ./hosts/pxe_server/configuration.nix
          ./modules
        ];
      };

      bastion0 = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/bastion0/configuration.nix
          ./modules
        ];
      };

      test-vm = nixpkgs.lib.nixosSystem {
        modules = [
          gallipedal.nixosModules.gallipedal
          ./hosts/test-vm/configuration.nix
          ./modules
        ];
      };
    };

  };
}
