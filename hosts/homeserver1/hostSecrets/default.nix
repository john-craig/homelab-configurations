{ pkgs, lib, config, ... }: {

  # This is the actual specification of the secrets.
  sops.secrets."tailscale/root/authkey" = {
    mode = "0440";

    sopsFile = ./tailscale.yaml;
  };

  sops.secrets."traefik/root/cloudflare_dns_token" = {
    mode = "0400";

    sopsFile = ./traefik.yaml;
  };
}
