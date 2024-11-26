{ pkgs, lib, config, ... }: {
  options = {
    voiceAssistant = {
      enable = lib.mkEnableOption "configuration for Voice Assistant";

      role =
        let
          # Define the allowed values as a list
          allowedValues = [ "station" "satellite" ];
        in
        lib.mkOption {
          type = lib.types.str;
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
      services.wyoming.openwakeword = {
        enable = true;
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
