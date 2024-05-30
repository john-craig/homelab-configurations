{
  description = "Home Lab Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    private-pkgs.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/homelab-packages";
    private-modules.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/homelab-modules";
  };

  outputs = { self, nixpkgs, disko, private-pkgs, private-modules }@inputs: {

    nixosConfigurations = {
      homeserver1 =
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.overlays = [ private-pkgs.overlays.default ]; }
            private-modules.nixosModules.smartctl-ssacli-exporter
            ./hosts/homeserver1/configuration.nix
          ];
        };

      media_kiosk =
        let
          pkgs = import nixpkgs { overlays = [ private-pkgs.overlays ]; };
        in
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs = { inherit pkgs; }; }
            ./hosts/media_kiosk/configuration.nix
            ./modules
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
    };

  };
}
