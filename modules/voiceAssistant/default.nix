{ pkgs, lib, config, ... }: {
  options = {
    voiceAssistant = {
      enable = lib.mkEnableOption "configuration for Voice Assistant";

      role = lib.mkOption {
        type = lib.types.enum [ "station" "satellite" ];
        default = "station"; # default value
        description = "Defines whether the configuration is for the base station or the satellite.";
      };
    };
  };

  config = lib.mkIf
    (config.voiceAssistant.enable &&
      config.voiceAssistant.role == "satellite")
    {
      # Satellite configurations
      services.wyoming.openwakeword = let 
        openwakeword = pkgs.wyoming-openwakeword.overrideAttrs (oldAttrs: {
          propagatedBuildInputs =  [
            pkgs.python3Packages.wyoming
            pkgs.python3Packages.ai-edge-litert
          ];

          patches = (oldAttrs.patches or []) ++ [
            (pkgs.writeText "use-ai-edge-litert.patch" ''
              diff --git a/wyoming_openwakeword/openwakeword.py b/wyoming_openwakeword/openwakeword.py
              index bbcf1fb..0b975ca 100644
              --- a/wyoming_openwakeword/openwakeword.py
              +++ b/wyoming_openwakeword/openwakeword.py
              @@ -6,7 +6,8 @@ from typing import Dict, List, Optional, TextIO
              import numpy as np

              try:
              -    import tflite_runtime.interpreter as tflite
              +#    import tflite_runtime.interpreter as tflite
              +     import ai_edge_litert.interpreter as tflite
              except ModuleNotFoundError:
                  import tensorflow.lite as tflite
              from wyoming.wake import Detection
            '')
          ];
        });
      in {
        enable = true;
        package = openwakeword;
        preloadModels = [
          "hey_rhasspy"
        ];

        uri = "tcp://0.0.0.0:10400";

        extraArgs = [
          "--debug"
        ];
      };

      services.wyoming.satellite = {
        enable = true;

        area = "Living Room";

        user = "display";
        group = "pipewire";

        uri = "tcp://0.0.0.0:10700";

        microphone.command = "arecord -D pipewire -r 16000 -c 1 -f S16_LE -t raw";
        sound.command = "aplay -D pipewire -r 22050 -c 1 -f S16_LE -t raw";

        sounds = {
          awake = "/home/display/media/by_category/audio/sounds/awake.wav";
          done = "/home/display/media/by_category/audio/sounds/done.wav";
        };

        extraArgs = [
          "--wake-uri"
          "tcp://0.0.0.0:10400"
          "--wake-word-name"
          "hey_rhasspy"

          "--startup-command"
          "echo $(date +%s) > /tmp/started.txt"
          "--detect-command"
          "echo $(date +%s) > /tmp/detecting.txt"
          "--detection-command"
          "echo $(date +%s) > /tmp/detected.txt"

          "--debug"
        ];
      };

    } // lib.mkIf
    (config.voiceAssistant.enable &&
      config.voiceAssistant.role == "station")
    {
      # Base station configuration
      services.wyoming.piper = {
        servers = {
          "base-station" = {
            enable = true;
            # see https://github.com/rhasspy/rhasspy3/blob/master/programs/tts/piper/script/download.py
            voice = "en_US-amy-medium";
            uri = "tcp://0.0.0.0:10200";
          };
        };
      };

      services.wyoming.faster-whisper = {
        servers = {
          "base-station" = {
            enable = true;
            # see https://github.com/rhasspy/rhasspy3/blob/master/programs/asr/faster-whisper/script/download.py
            model = "base";
            language = "en";
            uri = "tcp://0.0.0.0:10300";
            device = "cpu";
          };
        };
      };

    };
}
