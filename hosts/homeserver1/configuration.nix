# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [
      ./hardware-configuration.nix

      ./hostModules/linkArchiver.nix
      ./hostModules/summaryGenerator.nix
      ./hostModules/personalSite.nix
      ./hostModules/selfhosting.nix
      ./hostModules/apcupsd.nix
      ./hostModules/homeAssistant.nix
      ./hostModules/torrenting.nix
      ./hostModules/feedTheBeast.nix

      # ./hostModules/networking/tailscale.nix
      ./hostModules/networking/dns.nix
      ./hostModules/networking/nfs.nix
      ./hostModules/networking/wireguard.nix
      ./hostModules/networking/proxies.nix

      ./hostSecrets
    ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "homeserver1"; # Define your hostname.
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  networking.firewall.enable = false;

  # Enable emulation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.systemPackages = with pkgs; [
    smartmontools
    lsscsi
    lshw
    yt-dlp
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
  ];

  garbageCollect.enable = true;

  serviceProxies = {
    enable = true;

    resolverName = "chiliahedron-resolver";
    internalRules = "HeadersRegexp(`X-Real-Ip`, `(^192\.168\.[0-9]+\.[0-9]+)|(^10\.100\.0\.[0-9]+)`)";
    
    containers = {
      enable = true;
      networkName = "chiliahedron-services";
    };
    extraProxies = [
      {
        hostname = "home-assistant.chiliahedron.wtf";
        redirect = "http://192.168.1.8:8123";
      }
      # Cache proxies
      {
        hostname = "cache.pacman.chiliahedron.wtf";
        redirect = "http://192.168.1.5:4647";
      }
      {
        hostname = "cache.nix.chiliahedron.wtf";
        redirect = "http://192.168.1.5:5001";
      }
    ];
  };

  selfhosting.enable = true;

  personalSite.enable = true;
  linkArchiver.enable = true;
  summaryGenerator.enable = true;

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

  writingTracker = {
    enable = true;
    tokenPath = "/run/secrets/nocodb/service/api_token";
    documentPath = "/srv/documents/by_category/writing";
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      port = 9100;
    };

    smartctl-ssacli = {
      port = 9633;
      enable = true;
    };
  };

  userProfiles.service = {
    enable = true;
    authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5QNL0MP8yr7OD5rt4PpnL4Go++4rdmLFhhA5ypdpLbwfXqVEKOBnjxSn4Ux0BtHk8cIK5TT9wcigx9gLKaVX2aDSROITz5DMy2EuR09/kBp8xbaAeZQgyDB0C8YHPclPBN/25krDJNocWbJTnmBSwswXYJWGMUQZxfPMUyql3jy2fcxKUg39ATz9Qe9CmJpiBVGgTva0QpNWteTHOn7zwoHDhlIYCUygR/+X9LJCv7TvDPWaeYe9Z4+q58FMt9njTFAY9mXpa2qataIjk1KwoJWs2a8/vW2kYzbdOXH8KVxZuEpqgr4HCF+qdnFbuLtUfCFRKmCr3EI/+qPtUulUggusPm4d9tkfXlLytmydX7u4wJeOwYzsbtMLOPIOmGI8Q+jQUpc9zgbd34nat8LdD+vIayjpv8fU5lziaVVvkVP6EBF4UGGo/K0cdK8GGPoODJfUrNSr5m0Rh9IFHCp5QCvYxhOn4RXtIenx+0D9Am06Ab2G8S53l8yZwuMy7NBM="
    ];
  };

  users = {
    mutableUsers = true;

    groups."selfhosting".name = "selfhosting";
  };

  # Do not change
  system.stateVersion = "24.05";
}

