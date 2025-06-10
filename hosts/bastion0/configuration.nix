# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [
      ./hardware-configuration.nix

      ./hostModules/wireguard.nix
      # ./hostModules/headscale.nix

      ./hostSecrets
    ];

  networking.hostName = "bastion0"; # Define your hostname.

  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 51820 ];
  };

  garbageCollect.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  resourceCache.enable = lib.mkForce false;

  # Enable ACME with DNS challenge support
  # security.acme = {
  #   acceptTerms = true;
  #   defaults.email = "admin@chiliahedron.wtf";
  #   certs."headscale.chiliahedron.wtf" = {
  #     dnsProvider = "cloudflare";
  #     dnsResolver = "1.1.1.1:53";
  #     dnsPropagationCheck = true;
  #     webroot = null;
  #     environmentFile = config.sops.secrets."acme/root/cloudflare_dns_token".path;
  #     extraLegoFlags = [ "--dns.propagation-wait" "300s" ];
  #     reloadServices = [ "nginx" ];
  #   };
  # };

  services.nginx = {
    enable = true;

    # Custom global tuning
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    # # Override worker_connections
    # appendHttpConfig = ''
    #   events {
    #     worker_connections 4096;
    #   }
    # '';

    # Main virtual host for headscale
    # virtualHosts."headscale.chiliahedron.wtf" = {
    #   # forceSSL = true;
    #   enableACME = true;
    #   locations."/" = {
    #     proxyPass = "http://127.0.0.1:8083";
    #     proxyWebsockets = true;
    #   };
    # };

    # Redirect everything else to HTTPS
    virtualHosts."_" = {
      listen = [{ addr = "0.0.0.0"; port = 80; }];
      default = true;
      locations."/" = {
        return = "301 https://$server_name$request_uri";
      };
    };

    # Add stream block for TCP proxying
    streamConfig = ''
      server {
        listen 443;
        proxy_pass 10.100.0.2:443;
      }
    '';
  };

  # services.tailscale = {
  #   enable = true;
  #   extraUpFlags = [ "--accept-dns" ];
  #   authKeyFile = "/run/secrets/tailscale/root/authkey";
  # };

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  environment.systemPackages = with pkgs; [
    mtr
    sysstat
    lego
  ];

  userProfiles.service = {
    enable = true;

    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE+HFVBKYWOgTJ7R0v+Hj+yKnUPp0TepoKEBIPlL1jIe"
    ];
  };

  system.stateVersion = "23.11";
}
