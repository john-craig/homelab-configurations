{ pkgs, lib, config, ... }: {
  config = {
    # Disable NetworkManager's internal DNS resolution
    networking.networkmanager.dns = "systemd-resolved";

    # Configure DNS servers manually (this example uses Cloudflare and Google DNS)
    # IPv6 DNS servers can be used here as well.
    networking.nameservers = [
      "192.168.1.1"
    ];

    services.resolved = {
      enable = true;
      domains = [
        "~chiliahedron.wtf"
      ];
    };

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        server = [ "192.168.1.1" ];
        interface = [ "tailscale0" ];
        except-interface = [ "lo" ];
        bind-interfaces = true;

        address = [
          "/chiliahedron.wtf/100.69.200.65"
        ];
      };
    };
  };
}
