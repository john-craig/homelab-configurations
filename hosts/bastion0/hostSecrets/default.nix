{ pkgs, lib, config, ... }: {

  # This is the actual specification of the secrets.
  sops.secrets."tailscale/root/authkey" = {
    mode = "0440";

    sopsFile = ./tailscale.yaml;
  };

  sops.secrets."wireguard/root/private-key.b64" = {
    mode = "600";

    sopsFile = ./wireguard.yaml;
  };
}
