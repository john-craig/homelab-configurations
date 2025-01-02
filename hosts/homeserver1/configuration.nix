# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [
      ./hardware-configuration.nix

      ./hostModules/containerProxies.nix
      ./hostModules/link-archiver.nix
      ./hostModules/summary-generator.nix
      ./hostModules/personal-site.nix

      ./hostSecrets
    ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "homeserver1"; # Define your hostname.
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

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

  networking.firewall.enable = false;

  # Enable emulation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.systemPackages = with pkgs; [
    smartmontools
    lsscsi
    lshw
    nano
    curl
    git
    dig
    screen
    btrfs-progs
  ];

  systemd.tmpfiles.rules = [
    "A /srv/container user::rwx"
    "A /srv/container group::rwx"
    "A /srv/container mask::rwx"
    "A /srv/container other::---"

    "A /srv/documents user::rwx"
    "A /srv/documents group::rwx"
    "A /srv/documents mask::rwx"
    "A /srv/documents other::---"

    "Z /srv/downloads/lidarr 777"
    "Z /srv/downloads/tv-sonarr 777"
    "Z /srv/downloads/radarr 777"
    "Z /srv/downloads/readarr 777"
    "Z /srv/media/by_category/audio/music 777"
    "Z /srv/media/by_category/video/shows 777"
    "Z /srv/media/by_category/video/movies 777"
  ];

  containerProxies = {
    enable = true;
  };

  services.gallipedal = {
    enable = true;
    services = [
      "audiobookshelf"
      # "archivebox"
      "authelia"
      "code-server"
      "dev-blog"
      "gitea"
      "gotify"
      "grocy"
      "home-assistant"
      "homepage"
      "invidious"
      "jellyfin"
      "monitoring"
      "obsidian-remote"
      "onlyoffice"
      "owntracks"
      "paperless-ngx"
      "protonmail-bridge"
      "syncthing"
      "status-page"
      "registry"
      "rhasspy-base"
      "torrenting"
      # "traefik"
      "vaultwarden"
    ];

    proxyConf = {
      internalRules = "HeadersRegexp(`X-Real-Ip`, `(^192\.168\.[0-9]+\.[0-9]+)|(^100\.127\.79\.104)|(^100\.112\.189\.60)|(^100\.69\.200\.65)`)";
      network = "chiliahedron-services";
      tlsResolver = "chiliahedron-resolver";
    };
  };

  personal-site.enable = true;
  link-archiver.enable = true;
  summary-generator.enable = true;

  automatedBackups = {
    enable = true;
    role = "client";
    backupPaths = [
      "/srv/container"
      "/srv/documents"
    ];
  };

  disasterRecovery = {
    enable = true;
    role = "client";
  };

  selfUpdater.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    authKeyFile = "/run/secrets/tailscale/root/authkey";
    extraUpFlags = [ "--accept-dns=false" "--snat-subnet-routes=false" ];
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

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export         192.168.1.0/24(rw,fsid=0,no_subtree_check)
    /export/media   192.168.1.0/24(rw,nohide,insecure,no_subtree_check)
  '';

  services.openssh = {
    enable = true;
    allowSFTP = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      port = 9100;
    };

    apcupsd = {
      enable = true;
      port = 9162;
      apcupsdAddress = "0.0.0.0:3551";
    };

    smartctl-ssacli = {
      port = 9633;
      enable = true;
    };
  };

  services.apcupsd = {
    enable = true;
    configText = ''
      UPSTYPE usb
      UPSCABLE usb
      NISIP 0.0.0.0
      NISPORT 3551
    '';
    hooks = {
      doshutdown = ''
        # Fire a message to Gotify
        API_KEY=$(cat /run/secrets/gotify/notifier/api_key)
        curl -s -S --data '{"message": "'"Home Server on Back-Up Power"'", "title": "'"Home Server Backup Notifier"'", "priority":'"10"', "extras": {"client::display": {"contentType": "text/markdown"}}}' -H 'Content-Type: application/json' "https://gotify.chiliahedron.wtf/message?token=$API_KEY"
      '';
    };
  };

  users = {
    mutableUsers = true;

    groups."selfhosting".name = "selfhosting";

    users."service" = {
      isNormalUser = true;
      home = "/home/service";
      initialPassword = null;
      extraGroups = [ "wheel" ];

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5QNL0MP8yr7OD5rt4PpnL4Go++4rdmLFhhA5ypdpLbwfXqVEKOBnjxSn4Ux0BtHk8cIK5TT9wcigx9gLKaVX2aDSROITz5DMy2EuR09/kBp8xbaAeZQgyDB0C8YHPclPBN/25krDJNocWbJTnmBSwswXYJWGMUQZxfPMUyql3jy2fcxKUg39ATz9Qe9CmJpiBVGgTva0QpNWteTHOn7zwoHDhlIYCUygR/+X9LJCv7TvDPWaeYe9Z4+q58FMt9njTFAY9mXpa2qataIjk1KwoJWs2a8/vW2kYzbdOXH8KVxZuEpqgr4HCF+qdnFbuLtUfCFRKmCr3EI/+qPtUulUggusPm4d9tkfXlLytmydX7u4wJeOwYzsbtMLOPIOmGI8Q+jQUpc9zgbd34nat8LdD+vIayjpv8fU5lziaVVvkVP6EBF4UGGo/K0cdK8GGPoODJfUrNSr5m0Rh9IFHCp5QCvYxhOn4RXtIenx+0D9Am06Ab2G8S53l8yZwuMy7NBM="
      ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  # Do not change
  system.stateVersion = "24.05";
}

