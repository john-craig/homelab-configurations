{ pkgs, lib, config, ... }: {

  # This is the actual specification of the secrets.
  sops.secrets."tailscale/root/authkey" = {
    mode = "0440";

    sopsFile = ./tailscale.yaml;
  };
}
