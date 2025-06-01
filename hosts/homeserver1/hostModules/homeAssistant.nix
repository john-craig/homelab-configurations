{ pkgs, lib, config, ... }: {
  services.home-assistant = {
  enable = true;
  extraComponents = [
    # Components required to complete the onboarding
    "esphome"
    "met"
    "radio_browser"

    "pyipp"
    "tuya_sharing"
  ];
  config = {
    # external_url = "https://home-assistant.chiliahedron.wtf";
    # Includes dependencies for a basic setup
    # https://www.home-assistant.io/integrations/default_config/
    default_config = {};

    http = {
      use_x_forwarded_for = true;
      trusted_proxies = [
        "127.0.0.1"
        "::1"
        "192.168.1.8"   # Or the actual Traefik IP/subnet
      ];
    };
  };
};
}
