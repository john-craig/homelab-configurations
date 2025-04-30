{ pkgs, lib, config, ... }: {

  sops.secrets."gallipedal/secrets/archivebox/ADMIN_PASSWORD" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/archivebox/SEARCH_BACKEND_PASSWORD" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/gotify/GOTIFY_DEFAULTUSER_PASS" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/hakatime/HAKA_DB_PASS" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/invidious/POSTGRES_PASSWORD" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/nocodb/NC_DB" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/nocodb/POSTGRES_PASSWORD" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/torrenting/RSLSYNC_SECRET" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."gallipedal/secrets/torrenting/LIDARR_API_KEY" = {
    sopsFile = ./gallipedal.yaml;
  };

  sops.secrets."tailscale/root/authkey" = {
    mode = "0440";

    sopsFile = ./tailscale.yaml;
  };

  sops.secrets."wireguard/root/private-key.b64" = {
    mode = "600";

    sopsFile = ./wireguard.yaml;
  };

  sops.secrets."traefik/traefik/cloudflare_dns_token" = {
    mode = "0400";
    owner = "traefik";

    sopsFile = ./traefik.yaml;
  };
}
