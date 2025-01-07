{ pkgs, lib, config, ... }: {
  sops.secrets."gotify/display/client_token" = {
    owner = "display";
    mode = "0400";

    sopsFile = ./gotify.yaml;
  };
}
