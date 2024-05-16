# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, nix, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  networking.hostName = "bastion0"; # Define your hostname.

  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

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

              proxy_pass 192.168.1.8:443;
          }
      }
    '';
  };

  services.openssh = {
    enable = true;
    allowSFTP = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  services.tailscale.enable = true;

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  environment.systemPackages = with pkgs; [
    nano
    curl
    git
    inetutils
    mtr
    sysstat
    docker
    (python3.withPackages (ps: with ps; [
      requests
      urllib3
      websocket-client
      (pkgs.python3Packages.docker.overrideAttrs (oldAttrs: rec {
        pname = "docker";
        version = "6.1.3";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-qm0XgwBFul7wFo1eqjTTe+6xE5SMQTr/4dWZH8EfmiA=";
        };
      }))
      (buildPythonPackage rec {
        pname = "docker-compose";
        version = "1.29.2";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-TIzZ0h0jdBJ5PRi9MxEASe6a+Nqz/iwhO70HM5WbCbc=";
        };
        doCheck = false;
        propagatedBuildInputs = [
          (pkgs.python3Packages.docker.overrideAttrs (oldAttrs: rec {
            pname = "docker";
            version = "6.1.3";
            src = fetchPypi {
              inherit pname version;
              sha256 = "sha256-qm0XgwBFul7wFo1eqjTTe+6xE5SMQTr/4dWZH8EfmiA=";
            };
          }))
          pkgs.python3Packages.python-dotenv
          pkgs.python3Packages.dockerpty
          pkgs.python3Packages.setuptools
          pkgs.python3Packages.distro
          pkgs.python3Packages.pyyaml
          pkgs.python3Packages.jsonschema
          pkgs.python3Packages.jsondiff
          pkgs.python3Packages.docopt
          pkgs.python3Packages.texttable
        ];
      })
    ]))
  ];

  users = {
    mutableUsers = true;

    users."service" = {
      isNormalUser = true;
      home = "/home/service";
      initialPassword = null;
      extraGroups = [ "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE+HFVBKYWOgTJ7R0v+Hj+yKnUPp0TepoKEBIPlL1jIe"
      ];
    };
  };

  system.stateVersion = "23.11";
}
