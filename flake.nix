{
  description = "Home Lab Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-apocrypha.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/nixpkgs-apocrypha";
  };

  outputs = { self, nixpkgs, disko, nixpkgs-apocrypha }@inputs: {

    nixosConfigurations = {
      homeserver1 =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays.default ]; }
            nixpkgs-apocrypha.nixosModules.smartctl-ssacli-exporter
            ./hosts/homeserver1/configuration.nix
            nixpkgs-apocrypha.nixosModules.selfhosting
          ];
        };

      media_kiosk =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ nixpkgs-apocrypha.overlays.default ]; }
            ./hosts/media_kiosk/configuration.nix
            ./modules
            nixpkgs-apocrypha.nixosModules.selfhosting
            disko.nixosModules.disko
          ];
        };

      key_server = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/key_server/configuration.nix ];
      };

      pxe_server = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/pxe_server/configuration.nix ];
      };

      bastion0 = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/bastion0/configuration.nix ];
      };

      test-vm = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/test-vm/configuration.nix
          nixpkgs-apocrypha.nixosModules.selfhosting
        ];
      };
    };

  };
}
