{ pkgs, lib, config, ... }: {
  config = {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "both";
      authKeyFile = "/run/secrets/tailscale/root/authkey";
      extraUpFlags = [ "--accept-dns=false" "--snat-subnet-routes=false" ];
    };
  };
}
