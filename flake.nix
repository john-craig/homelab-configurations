{
  description = "Home Lab Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-apocrypha.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/nixpkgs-apocrypha";

    gallipedal.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/gallipedal-module";
  };

  outputs = { self, nixpkgs, disko, home-manager, gallipedal, nixpkgs-apocrypha }@inputs: {

    nixosConfigurations = {
      homeserver1 =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays.default ]; }
            gallipedal.nixosModules.gallipedal
            nixpkgs-apocrypha.nixosModules.smartctl-ssacli-exporter
            ./hosts/homeserver1/configuration.nix
            ./global/defaults/configuration.nix
          ];
        };

      media_kiosk =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays.default ]; }
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            gallipedal.nixosModules.gallipedal
            ./hosts/media_kiosk/configuration.nix
            ./global/defaults/configuration.nix
          ];
        };

      key_server = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/key_server/configuration.nix
          ./global/defaults/configuration.nix
        ];
      };

      pxe_server = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/pxe_server/configuration.nix
          ./global/defaults/configuration.nix
        ];
      };

      bastion0 = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/bastion0/configuration.nix
          ./global/defaults/configuration.nix
        ];
      };

      test-vm = nixpkgs.lib.nixosSystem {
        modules = [
          gallipedal.nixosModules.gallipedal
          ./hosts/test-vm/configuration.nix
          ./global/defaults/configuration.nix
        ];
      };
    };

  };
}
