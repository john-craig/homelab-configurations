# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [
      ./hardware-configuration.nix

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
    allowedTCPPorts = [ 22 80 443 ];
  };

  garbageCollect.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  services.nginx = {
    enable = true;
    config = ''
      events {
          worker_connections  4096;  ## Default: 1024
      }

      http {
          server {
              listen 80;
              server_name _;
              return 301 https://$server_name$request_uri;
          }
      }

      stream {
          server {
              listen 443;
              #server_name _;
              # We need to pass the request to server so that
              # if it is hosting multiple sites hosted, it knows which one to serve
              #proxy_set_header Host $server_name;

              proxy_pass 100.69.200.65:443;
          }
      }
    '';
  };

  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-dns" ];
    authKeyFile = "/run/secrets/tailscale/root/authkey";
  };

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  environment.systemPackages = with pkgs; [
    mtr
    sysstat
  ];

  userProfiles.service = {
    enable = true;

    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE+HFVBKYWOgTJ7R0v+Hj+yKnUPp0TepoKEBIPlL1jIe"
    ];
  };

  system.stateVersion = "23.11";
}
