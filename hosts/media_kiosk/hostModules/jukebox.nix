{ pkgs, lib, config, ... }: {
  options = {
    jukebox.enable = lib.mkEnableOption "configuration for Jukebox Mode";
  };

  config = lib.mkIf config.jukebox.enable {
    # Enable sound.
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      systemWide = true;

      configPackages = [
        # Note: Echo cancellation seems to nuke audio quality, still not 100%
        #       sure was to why.
        # (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/10-common.conf" ''
        #   context.modules = [
        #     { name = libpipewire-module-echo-cancel } 
        #   ]
        # '')
        (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/50-combined-sink.conf" ''
          context.modules = [
            {
              name = libpipewire-module-combine-stream
              args = {
                combine.mode = sink
                node.name = "broadcast-sink"
                node.description = "broadcast-sink"
                -- combine.latency-compensate = true   # if true, match latencies by adding delays
                combine.props = {
                  audio.position = [ MONO ]
                }
                stream.props = {
                }
                stream.rules = [
                  {
                    matches = [ { media.class = "Audio/Sink" } ]
                    actions = { create-stream = { } }
                  }
                ]
              }
            } 
          ]
        '')
        (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/50-combined-source.conf" ''
          context.modules = [
            {
              name = libpipewire-module-combine-stream
              args = {
                combine.mode = source
                node.name = "reciever-source"
                node.description = "reciever-source"
                combine.latency-compensate = true   # if true, match latencies by adding delays
                combine.props = {
                  audio.position = [ MONO ]
                }
                stream.props = {
                }
                stream.rules = [
                  {
                    matches = [ { media.class = "Audio/Source" } ]
                    actions = { create-stream = { } }
                  }
                ]
              }
            }
          ]
        '')
      ];

      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      wireplumber = {
        enable = true;
        extraConfig = {
          "5-bluez" = {
            # "monitor.bluez.properties" = {
            #   bluez5.enable-sbc-xq = true;
            #   bluez5.enable-msbc = true;
            #   bluez5.enable-hw-volume = true;
            #   bluez5.codecs = [ "sbc" "sbc_xq" ];
            # };
            "monitor.bluez.rules" = [
              {
                matches = [
                  {
                    "device.name" = "bluez_card.2C_FD_B3_1C_1C_10";
                  }
                ];
                actions = {
                  update-props = {
                    "bluez5.auto-connect" = [ "a2dp_source" ];
                    "device.profile" = "a2dp-source";
                  };
                };
              }
              # {
              #   matches = [
              #     {
              #       # Anker PowerConf
              #       device.name = "bluez_card.2C_FD_B3_1C_1C_10";
              #     }
              #   ];
              #   actions = {
              #     update-props = {
              #       bluez5.auto-connect  = [ "a2dp-source" ];
              #       device.profile = "a2dp-source";
              #     };
              #   };
              # }
              # {
              #   matches = [
              #     {
              #       # Cavalier Air (CAV5)
              #       device.name = "bluez_card.28_37_13_08_6E_30";
              #     }
              #   ];
              #   actions.update-props = {
              #     device.profile = "headset-head-unit";
              #     bluez5.headset-roles = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
              #   };
              # }
              # {
              #   matches = [
              #     {
              #       # Pixel 4a 5G
              #       device.name = "bluez_card.58_24_29_71_24_CF";
              #     }
              #   ];
              #   actions.update-props = {
              #     api.bluez5.codec = "sbc_xq";
              #     device.profile = "a2dp-source";
              #     bluez5.codecs = [ "sbc_xq" ];
              #   };
              # }
              # {
              #   matches = [
              #     {
              #       # Pixel 4a 5G
              #       node.name = "bluez_input.58_24_29_71_24_CF.2";
              #     }
              #   ];
              #   actions.update-props = {
              #     target.object = "broadcast-sink";
              #   };
              # }
              # {
              #   matches = [
              #     {
              #       # This matches all cards.
              #       device.name = "bluez_card.*";
              #     }
              #   ];
              #   actions.update-props = {
              #     bluez5.auto-connect  = [ "a2dp_sink" "a2dp_source" "hfp_hf" "hsp_hs" ];
              #     device.profile = "a2dp-sink";
              #     bluez5.profile = "a2dp-sink";
              #   };
              # }
            ];
          };
        };
      };
    };

    hardware.bluetooth = {
      enable = true; # enables support for Bluetooth
      powerOnBoot = true; # powers up the default Bluetooth controller on boot
      package = pkgs.bluez;
      settings = {
        General = {
          Name = "Media Kiosk";
          Enable = "Source,Sink,Headset,Gateway,Control,Media";
          Disable = "Socket";
          FastConnectable = "true";
          Experimental = "true";
          KernelExperimental = "true";
          MultiProfile = "multiple";
        };
      };
    };
    # This is ugly but it's the best way to override ExecStart, apparently
    systemd.services."bluetooth".serviceConfig.ExecStart = [
      ""
      "${pkgs.bluez}/libexec/bluetooth/bluetoothd -d -f /etc/bluetooth/main.conf --compat"
    ];

    environment.systemPackages = with pkgs; [
      alsa-utils
    ];
  };
}
