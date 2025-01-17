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
            "monitor.bluez.properties" = {
              bluez5.enable-sbc-xq = true;
              bluez5.enable-msbc = true;
              bluez5.enable-hw-volume = true;
              bluez5.codecs = [ "sbc" "sbc_xq" ];
            };
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
                              "node.name" = "bluez_output.${deviceAddr}.1";
                            }
                          ];

                          actions.update-props =
                            lib.attrsets.optionalAttrs (device.role == "sink")
                              {
                                "api.bluez5.profile" = "a2dp-sink";
                              } //
                            lib.attrsets.optionalAttrs (device.role == "both") {
                              "api.bluez5.profile" = "headset-head-unit";
                            };
                        }
                        # {
                        #   matches = [
                        #     {
                        #       "device.name" = "bluez_card.${deviceAddr}";
                        #     }
                        #   ];

                        #   actions.update-props =
                        #     lib.attrsets.optionalAttrs (device.role == "source")
                        #       {
                        #         "bluez5.auto-connect" = [ "a2dp_source" ];
                        #       } //
                        #     lib.attrsets.optionalAttrs (device.role == "sink")
                        #       {
                        #         "bluez5.auto-connect" = [ "a2dp_sink" ];
                        #         "device.profile" = "a2dp-sink";
                        #       } //
                        #     lib.attrsets.optionalAttrs (device.role == "both") {
                        #       "device.profile" = "headset-head-unit";
                        #       "bluez5.headset-roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
                        #     };
                        # }
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
                ) [ ]
                config.jukebox.devices;
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
    systemd.services."bluetooth-reconnect" = {
      enable = true;
      path = [ pkgs.bluez ];
      script =
        let
          reconnectCmds = lib.lists.foldl
            (acc: device:
              acc + ''
                # Begin the connection for ${device.address}
                echo -e "select ${device.controller}\nconnect ${device.address}" | bluetoothctl

                # Define the maximum number of attempts
                MAX_ATTEMPTS=6

                # Initialize the attempt counter
                attempt=0

                # Loop up to MAX_ATTEMPTS
                while [ $attempt -lt $MAX_ATTEMPTS ]; do
                  # Increment the attempt counter
                  attempt=$((attempt + 1))
                  
                  # Check if the device has finished connecting
                  if echo -e "select ${device.controller}\ndevices Connected" | bluetoothctl | grep ${device.address}; then
                    # If the pattern is found, continue
                    echo "Device ${device.address} connected, continuing..."
                    break
                  else
                    # If not found, wait 5 seconds and try again
                    echo "Device ${device.address} not yet connected. Attempt $attempt of $MAX_ATTEMPTS. Retrying in 5 seconds..."
                    sleep 5
                  fi
                done

                # If the loop ends and the pattern wasn't found after MAX_ATTEMPTS
                if [ $attempt -eq $MAX_ATTEMPTS ]; then
                  echo "WARNING: Devices ${device.address} not found after $MAX_ATTEMPTS attempts. Continuing..."
                fi
              ''
            ) ""
            config.jukebox.devices;
        in
        ''
          #!/bin/bash
          ${reconnectCmds}
        '';
      serviceConfig = {
        User = "service";
        Type = "oneshot";
      };

      after = [ "bluetooth.service" ]; # Run after the Bluetooth service starts
      bindsTo = [ "bluetooth.service" ]; # Ensure Bluetooth is started before this service
      wantedBy = [ "bluetooth.service" ]; # Ensure Bluetooth is started before this service
    };

    environment.systemPackages = with pkgs; [
      alsa-utils
    ];
  };
}
