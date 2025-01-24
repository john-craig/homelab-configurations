# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, user-environments, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./disk-configuration.nix

      ./hostModules/notifier.nix

      ./hostModules/kiosk.nix
      ./hostModules/jukebox.nix

      ./hostModules/screenSaver.nix
      ./hostModules/morningAlarm.nix

      ./hostSecrets
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "media-kiosk"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  environment.systemPackages = with pkgs; [ ];

  # Kiosk Mode
  kiosk.enable = true;

  # Jukebox Mode
  jukebox = {
    enable = true;

    devices = [
      # {
      #   # Kitchen Speaker (A8)
      #   "address" = "35:F1:7E:40:E2:65";
      #   "controller" = "8C:88:4B:45:CC:11";
      #   "role" = "sink";
      # }
      # {
      #   # Bathroom Speaker (A8)
      # "address" = "3B:C4:CF:3E:EA:0A";
      # "controller" = "8C:88:4B:45:CC:11";
      # "role" = "sink";
      # }
      {
        # Bathroom Speaker (A15)
        "address" = "FC:58:FA:88:89:AC";
        "controller" = "8C:88:4B:45:CC:11";
        "role" = "sink";
      }
      {
        # Anker PowerConf
        "address" = "2C:FD:B3:1C:1C:10";
        "controller" = "8C:88:4B:45:CC:11";
        "role" = "source"; # For now only a source
      }
      {
        # Cavalier Air (CAV5)
        "address" = "28:37:13:08:6E:30";
        "controller" = "8C:88:4B:45:CC:11";
        "role" = "sink";
      }
      {
        # Pixel 4a 5G
        "address" = "58:24:29:71:24:CF";
        "controller" = "8C:88:4B:45:CC:11";
        "role" = "source";
        "broadcast" = true;
      }
    ];
  };

  notifier.enable = true;

  voiceAssistant = {
    enable = true;
    role = "satellite";
  };

  # Screen Saver
  screenSaver = {
    enable = true;
    urls = [
      "https://status.chiliahedron.wtf/recent.html"
      "https://grafana.chiliahedron.wtf/public-dashboards/84d4b99c333d4f7d94c495a66c1af3c6?orgId=1&refresh=5m"
      "https://gotify.chiliahedron.wtf/#/"
    ];
  };

  # Morning Alarm
  morningAlarm = {
    enable = true;
    urls = [
      "https://www.youtube.com/watch?v=hNrt704O0tU"
      "https://www.youtube.com/watch?v=pbTO0w-fWKE"
      "https://www.youtube.com/watch?v=rGHwRodMyFY"
      "https://www.youtube.com/watch?v=WyihFDfE9Q4"
      "https://www.youtube.com/watch?v=6VRSCHmkz7I"
      "https://www.youtube.com/watch?v=kvMxUish5yU"
      "https://www.youtube.com/watch?v=MGUMdxa_Yi8"
      "https://www.youtube.com/watch?v=1picLdoFEWY"
      "https://www.youtube.com/watch?v=llVpzBjYWc0"
      "https://www.youtube.com/watch?v=Js5yHVbtFTQ"
      "https://www.youtube.com/watch?v=yaoAv4-FcEI"
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

  userProfiles = {
    service = {
      enable = true;
      authorizedKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlROWOhaHkVxXszd4hfOVhjPx4k5CDJT+bkb+dK/hety+j0L5PbKb6ta1eQrOrhwL4DsKi13KLIVsIyteg7TdBd+fKW1NJzljztsool4dE/b6/hBN8ha4FGVY1IoS6uy44dE7rBJ8uXle/HxMwCmQwpKLDwOUGAun4DwtxQjY0Xy5fu4r3E21FUmRhF7QJ0lSZ2sHMhm2mvGsVKhZLeEyf3aXb+b81aR9anIeClazosPj9li9M8QgWamqQ+YD9w5J1RcmtbAKf4k4NAHYS786vsuR3NnaotF4jIV9olBZhRWfSeeR9E3hc6mRxbJKy2ME41sKpMoB/b7Of78voMWJ5CSvm0NQVK46QuEcA7fiwn9AsILM22e/VXbSAWa5oxW8lfUVLHax2jH4riq9pXkBM7NClmes0ns698B8ND2qpPOAEGX0oS9DCdmCERwHyRBQUAxYhye4yzq0iiH5d/CBz7UqoJ+eRucG/+uL08wFTCVA9NP5P/BZIN1sW7yZgyss="
      ];
    };
    display = {
      enable = true;
      authorizedKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlROWOhaHkVxXszd4hfOVhjPx4k5CDJT+bkb+dK/hety+j0L5PbKb6ta1eQrOrhwL4DsKi13KLIVsIyteg7TdBd+fKW1NJzljztsool4dE/b6/hBN8ha4FGVY1IoS6uy44dE7rBJ8uXle/HxMwCmQwpKLDwOUGAun4DwtxQjY0Xy5fu4r3E21FUmRhF7QJ0lSZ2sHMhm2mvGsVKhZLeEyf3aXb+b81aR9anIeClazosPj9li9M8QgWamqQ+YD9w5J1RcmtbAKf4k4NAHYS786vsuR3NnaotF4jIV9olBZhRWfSeeR9E3hc6mRxbJKy2ME41sKpMoB/b7Of78voMWJ5CSvm0NQVK46QuEcA7fiwn9AsILM22e/VXbSAWa5oxW8lfUVLHax2jH4riq9pXkBM7NClmes0ns698B8ND2qpPOAEGX0oS9DCdmCERwHyRBQUAxYhye4yzq0iiH5d/CBz7UqoJ+eRucG/+uL08wFTCVA9NP5P/BZIN1sW7yZgyss="
      ];
    };
  };

  users = {
    mutableUsers = true;

    groups."selfhosting".name = "selfhosting";
  };


  # services.gallipedal = {
  #   enable = true;
  #   services = [
  #     "rhasspy-satellite"
  #     "timeflip-tracker"
  #   ];
  # };

  # Open ports in the firewall.
  networking.firewall.enable = false;

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

