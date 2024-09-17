# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "homeserver1"; # Define your hostname.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  systemd.services.NetworkManager-wait-online.enable = false;

  networking.firewall.enable = false;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  environment.systemPackages = with pkgs; [
    smartmontools
    lsscsi
    lshw
    nano
    curl
    git
    btrfs-progs
    obsidian-link-archiver
    status-page-generator
  ];

  services.gallipedal = {
    enable = true;
    services = [
      "audiobookshelf"
      "archivebox"
      "authelia"
      "code-server"
      "dev-blog"
      "gitea"
      "gotify"
      "grocy"
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
      "traefik"
    ];

    proxyConf = {
      internalRules = "HeadersRegexp(`X-Real-Ip`, `(^192\.168\.[0-9]+\.[0-9]+)|(^100\.127\.79\.104)|(^100\.112\.189\.60)`)";
      network = "chiliahedron-services";
      tlsResolver = "chiliahedron-resolver";
    };
  };

  # System Daemon Timers
  systemd.timers."archive-obsidian-links" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Unit = "archive-obsidian-links.service";
    };
  };

  systemd.services."archive-obsidian-links" = {
    enable = true;
    script = ''
      # Perform the archive
      ${pkgs.obsidian-link-archiver}/bin/obsidian-link-archiver /srv/documents/by_category/vault/notes
      ${pkgs.obsidian-link-archiver}/bin/obsidian-link-archiver /srv/documents/by_category/vault/projects
      
      # Restart archivebox to kill off erroneous Chrome processes
      ${pkgs.docker}/bin/docker restart archivebox
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "service";
    };
  };

  systemd.timers."generate-project-summary" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      Unit = "generate-project-summary.service";
    };
  };

  systemd.services."generate-project-summary" = {
    enable = true;
    script = ''
      # Regenerate the files
      ${pkgs.status-page-generator}/bin/status-generator /srv/documents/by_category/vault /srv/container/status-page
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };


  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    authKeyFile = "/root/tailscale/authkey.b64";
    extraUpFlags = [ "--advertise-routes=192.168.0.0/24" "--snat-subnet-routes=false" ];
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
        curl -s -S --data '{"message": "'"Home Server on Back-Up Power"'", "title": "'"Home Server Backup Notifier"'", "priority":'"10"', "extras": {"client::display": {"contentType": "text/markdown"}}}' -H 'Content-Type: application/json' "https://gotify.chiliahedron.wtf/message?token=AXFQr-2KNOgy-Vv"
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
      extraGroups = [ "wheel" "docker" "selfhosting" ];

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

