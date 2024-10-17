{ pkgs, lib, config, ... }: {
  options = {
    voice-assistant = {
      enable = lib.mkEnableOption "configuration for Voice Assistant Base Station";
    };
  };

  config = lib.mkIf config.voice-assistant.enable {
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
  };
}
