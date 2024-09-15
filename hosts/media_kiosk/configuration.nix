# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./disk-configuration.nix

      ./hostModules/kiosk.nix
      ./hostModules/jukebox.nix
      ./hostModules/screen-saver.nix
      ./hostModules/notifier.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "media-kiosk"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Kiosk Mode
  kiosk.enable = true;

  # Jukebox Mode
  jukebox.enable = true;

  notifier.enable = true;

  # Screen Saver
  screen-saver = {
    enable = true;
    urls = [
      "https://owntracks.chiliahedron.wtf/last/index.html"
      "https://status.chiliahedron.wtf/recent.html"
      "https://grafana.chiliahedron.wtf/public-dashboards/84d4b99c333d4f7d94c495a66c1af3c6?orgId=1&refresh=5m"
    ];
  };

  virtualisation.containers.registries.search = [ "registry.chiliahedron.wtf" ];

  services.prometheus.exporters = {
    node = {
      enable = true;
      port = 9100;
    };

    smartctl = {
      enable = true;
      port = 9633;
      devices = [ "/dev/mmcblk1" ];
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    mutableUsers = true;

    groups."selfhosting".name = "selfhosting";

    users."service" = {
      isNormalUser = true;
      initialPassword = null;
      extraGroups = [ "wheel" "docker" "selfhosting" ];

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlROWOhaHkVxXszd4hfOVhjPx4k5CDJT+bkb+dK/hety+j0L5PbKb6ta1eQrOrhwL4DsKi13KLIVsIyteg7TdBd+fKW1NJzljztsool4dE/b6/hBN8ha4FGVY1IoS6uy44dE7rBJ8uXle/HxMwCmQwpKLDwOUGAun4DwtxQjY0Xy5fu4r3E21FUmRhF7QJ0lSZ2sHMhm2mvGsVKhZLeEyf3aXb+b81aR9anIeClazosPj9li9M8QgWamqQ+YD9w5J1RcmtbAKf4k4NAHYS786vsuR3NnaotF4jIV9olBZhRWfSeeR9E3hc6mRxbJKy2ME41sKpMoB/b7Of78voMWJ5CSvm0NQVK46QuEcA7fiwn9AsILM22e/VXbSAWa5oxW8lfUVLHax2jH4riq9pXkBM7NClmes0ns698B8ND2qpPOAEGX0oS9DCdmCERwHyRBQUAxYhye4yzq0iiH5d/CBz7UqoJ+eRucG/+uL08wFTCVA9NP5P/BZIN1sW7yZgyss="
      ];
    };

    users."display" = {
      isNormalUser = true;
      home = "/home/display";
      initialPassword = null;
      extraGroups = [ "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlROWOhaHkVxXszd4hfOVhjPx4k5CDJT+bkb+dK/hety+j0L5PbKb6ta1eQrOrhwL4DsKi13KLIVsIyteg7TdBd+fKW1NJzljztsool4dE/b6/hBN8ha4FGVY1IoS6uy44dE7rBJ8uXle/HxMwCmQwpKLDwOUGAun4DwtxQjY0Xy5fu4r3E21FUmRhF7QJ0lSZ2sHMhm2mvGsVKhZLeEyf3aXb+b81aR9anIeClazosPj9li9M8QgWamqQ+YD9w5J1RcmtbAKf4k4NAHYS786vsuR3NnaotF4jIV9olBZhRWfSeeR9E3hc6mRxbJKy2ME41sKpMoB/b7Of78voMWJ5CSvm0NQVK46QuEcA7fiwn9AsILM22e/VXbSAWa5oxW8lfUVLHax2jH4riq9pXkBM7NClmes0ns698B8ND2qpPOAEGX0oS9DCdmCERwHyRBQUAxYhye4yzq0iiH5d/CBz7UqoJ+eRucG/+uL08wFTCVA9NP5P/BZIN1sW7yZgyss="
      ];
    };
  };

  systemd.timers."morning-alarm" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 6:00:00";
      Unit = "morning-alarm.service";
    };
  };

  systemd.services."morning-alarm" = {
    enable = true;
    script = ''
      
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "display";
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  services.gallipedal = {
    enable = true;
    services = [
      "rhasspy-satellite"
      "timeflip-tracker"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    git

    rhasspy-microphone-cli-hermes
    rhasspy-speakers-cli-hermes

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
          pkgs.python3Packages.docopt
          pkgs.python3Packages.texttable
        ];
      })
    ]))
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    allowSFTP = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # Open ports in the firewall.
  networking.firewall.enable = false;

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

