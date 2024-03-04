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

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "us"; # keyboard layout
    libinput.enable = true;

    # Let lightdm handle autologin
    displayManager.lightdm = {
      enable = true;
      # autoLogin = {
      #   timeout = 0;
      # };
    };

    # Start openbox after autologin
    windowManager.openbox.enable = true;
    displayManager = {
      defaultSession = "none+openbox";
      autoLogin = {
        user = "display";
        enable = true;
      };
    };
  };

  # Overlay to set custom autostart script for openbox
  nixpkgs.overlays = with pkgs; [
    (_self: super: {
      openbox = super.openbox.overrideAttrs (_oldAttrs: rec {
        postFixup = ''
          ln -sf /etc/openbox/autostart $out/etc/xdg/openbox/autostart
        '';
      });
    })
  ];

  # By defining the script source outside of the overlay, we don't have to
  # rebuild the package every time we change the startup script.
  environment.etc."openbox/autostart".source = pkgs.writeScript "autostart" ''
    #!${pkgs.bash}/bin/bash
    # End all lines with '&' to not halt startup script execution

    # Keep screen on
    xset -dpms     & # Disable DPMS (Energy Star) features
    xset s off     & # Disable screensaver
    xset s noblank & # Don't blank video device

    # Start chromium
    chromium --remote-debugging-port=9222 --remote-allow-origins=* &
  '';

  # Prevent hibernating
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  powerManagement.enable = false;

  # Enable sound.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    #socketActivation = true;

    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    wireplumber.enable = true;
  };

  environment.etc = {
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
      bluez_monitor.enabled = true

      bluez_monitor.properties = {
        ["bluez5.enable-sbc-xq"] = true,
        ["bluez5.enable-msbc"] = true,
        ["bluez5.enable-hw-volume"] = true,
        ["bluez5.codecs"] = "[sbc sbc_xq]",
        ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
      }

      bluez_monitor.rules = {
        {
          matches = {
            {
              -- This matches all cards.
              { "device.name", "matches", "bluez_card.*" },
            },
          },
          apply_properties = {
            ["bluez5.auto-connect"]  = "[ hfp_hf hsp_hs a2dp_sink ]",
          }
        },
        {
          matches = {
            {
              -- Anker PowerConf
              { "device.name", "matches", "bluez_card.2C_FD_B3_1C_1C_10" },
              -- Cavalier Air (CAV5)
              { "device.name", "matches", "bluez_card.28_37_13_08_6E_30" },
            },
          },
          apply_properties = {
            ["device.profile"] = "headset-head-unit",
          }
        }
      }
    '';

    # "pipewire/pipewire.conf.d/99-null-sink".text = ''
    #   context.objects = [
    #       {   factory = adapter
    #           args = {
    #               factory.name     = support.null-audio-sink
    #               node.name        = "my-sink"
    #               media.class      = Audio/Sink
    #               audio.position   = [ FL FR FC LFE RL RR ]
    #               monitor.channel-volumes = true
    #               adapter.auto-port-config = {
    #                   mode = dsp
    #                   monitor = true
    #                   position = preserve
    #               }
    #           }
    #       }
    #   ]
    # '';
  };

  services.pipewire.extraConfig.pipewire = {
    "31-default-sink.conf" = {
      context.properties = {
        default.configured.audio.sink = {
          #name = "alsa_output.pci-0000_00_0e.0.hdmi-stereo"; 
          name = "broadcast-sink";
        };
      };
    };

    "91-broadcast-sink" = {
      context.modules = [
        {
          name = "libpipewire-module-combine-stream";
          args = {
            combine.mode = "sink";
            node.name = "broadcast-sink";
            node.description = "This sink broadcasts to all available sinks";
            combine.latency-compensate = false; # if true, match latencies by adding delays
            combine.props = {
              audio.position = [ "FL" "FR" ];
            };
            stream.props = { };
            stream.rules = [
              {
                matches = [{ media.class = "Audio/Sink"; }];
                actions = { create-stream = { }; };
              }
            ];
          };
        }
      ];
    };
  };

  hardware.bluetooth = {
    enable = true; # enables support for Bluetooth
    powerOnBoot = true; # powers up the default Bluetooth controller on boot
    package = pkgs.bluez;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
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

  security.sudo.extraRules = [
    {
      users = [ "service" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    ungoogled-chromium
    git
    rsync
    usbutils
    alsa-utils
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

