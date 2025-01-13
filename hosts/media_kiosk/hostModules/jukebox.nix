{ pkgs, lib, config, ... }: {
  options = {
    jukebox = {
      enable = lib.mkEnableOption "configuration for Jukebox Mode";

      devices = lib.mkOption {
        default = [ ];
        type = lib.types.listOf (lib.types.submodule {
          options = {
            address = lib.mkOption {
              type = lib.types.str;
              description = "The MAC address of the device";
            };

            controller = lib.mkOption {
              type = lib.types.str;
              description = "The MAC address of the controller to use for the device";
            };

            role = lib.mkOption {
              type = lib.types.enum [
                "sink"
                "source"
                "both"
              ];
              description = "Whether the device should be treated as a speaker, a microphone, or both";
            };

            broadcast = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "When the device is a source, determines if it should be broadcast over all speakers";
            };
          };
        });
      };
    };
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
                combine.latency-compensate = true   # if true, match latencies by adding delays
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
            "monitor.bluez.rules" =
              lib.lists.foldl
                (
                  acc: device:
                    let
                      deviceAddr = builtins.replaceStrings [ ":" ] [ "_" ] device.address;
                    in
                    (
                      acc ++ [
                        {
                          matches = [
                            {
                              "device.name" = "bluez_card.${deviceAddr}";
                            }
                          ];

                          actions.update-props = 
                            lib.attrsets.optionalAttrs (device.role == "source") {
                              "bluez5.auto-connect" = [ "a2dp_source" ];
                              "device.profile" = "a2dp-source";
                            } // 
                            lib.attrsets.optionalAttrs (device.role == "both") {
                              "device.profile" = "headset-head-unit";
                              "bluez5.headset-roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
                            }; # No need to handle the `sink` case, as it is the default
                        }
                      ] ++ lib.lists.optionals (device.broadcast) [
                        {
                          matches = [
                            {
                              "node.name" = "bluez_input.${deviceAddr}.2";
                            }
                          ];
                          actions.update-props = {
                            "target.object" = "broadcast-sink";
                          };
                        }
                      ]
                    )
                ) [{
                matches = [
                  {
                    # This matches all cards.
                    "device.name" = "bluez_card.*";
                  }
                ];
                actions.update-props = {
                  "bluez5.auto-connect" = [ "a2dp_sink" "a2dp_source" "hfp_hf" "hsp_hs" ];
                  "device.profile" = "a2dp-sink";
                };
              }]
                config.jukebox.devices;

            # [
            #   {
            #     matches = [
            #       {
            #         # Anker PowerConf
            #         "device.name" = "bluez_card.2C_FD_B3_1C_1C_10";
            #       }
            #     ];
            #     actions = {
            #       update-props = {
            #         "bluez5.auto-connect" = [ "a2dp_source" ];
            #         "device.profile" = "a2dp-source";
            #       };
            #     };
            #   }
            #   # {
            #   #   matches = [
            #   #     {
            #   #       # Cavalier Air (CAV5)
            #   #       device.name = "bluez_card.28_37_13_08_6E_30";
            #   #     }
            #   #   ];
            #   #   actions.update-props = {
            #       # device.profile = "headset-head-unit";
            #       # bluez5.headset-roles = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
            #   #   };
            #   # }
            #   {
            #     matches = [
            #       {
            #         # Pixel 4a 5G
            #         device.name = "bluez_card.58_24_29_71_24_CF";
            #       }
            #     ];
            #     actions.update-props = {
            #       api.bluez5.codec = "sbc_xq";
            #       device.profile = "a2dp-source";
            #       bluez5.codecs = [ "sbc_xq" ];
            #     };
            #   }
            #   {
            #     matches = [
            #       {
            #         # Pixel 4a 5G
            #         node.name = "bluez_input.58_24_29_71_24_CF.2";
            #       }
            #     ];
            #     actions.update-props = {
            #       target.object = "broadcast-sink";
            #     };
            #   }
            #   {
            #     matches = [
            #       {
            #         # This matches all cards.
            #         device.name = "bluez_card.*";
            #       }
            #     ];
            #     actions.update-props = {
            #       bluez5.auto-connect  = [ "a2dp_sink" "a2dp_source" "hfp_hf" "hsp_hs" ];
            #       device.profile = "a2dp-sink";
            #     };
            #   }
            # ];
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

    # Set up automatic reconnection
    systemd.services."bluetooth-connect" = {
      enable = true;
      path = [ pkgs.bluez ];
      script =
        let
          bluetoothDevices = [
            {
              # Kitchen Speaker
              "controller" = "8C:88:4B:45:CC:11";
              "address" = "35:F1:7E:40:E2:65";
            }
            {
              # Bathroom Speaker
              "controller" = "8C:88:4B:45:CC:11";
              "address" = "3B:C4:CF:3E:EA:0A";
            }
          ];

          reconnectCmds = lib.lists.foldl
            (acc: device:
              acc + ''
                echo -e "select ${device.controller}\nconnect ${device.address}" | bluetoothctl
              ''
            ) ""
            bluetoothDevices;
        in
        ''
          ${reconnectCmds}
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    environment.systemPackages = with pkgs; [
      alsa-utils
    ];
  };
}
