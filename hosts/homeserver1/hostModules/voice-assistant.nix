{ pkgs, lib, config, ... }: {
  options = {
    voice-assistant = {
      enable = lib.mkEnableOption "configuration for Voice Assistant Base Station";
    };
  };

  config = lib.mkIf config.voice-assistant.enable {
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
