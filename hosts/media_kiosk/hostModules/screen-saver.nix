{ pkgs, lib, config, ... }: {
  options = {
    screen-saver = {
      enable = lib.mkEnableOption "configuration for Screen Saver Mode";

      urls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = lib.mdDoc ''
          A list of URLs to loop over.
        '';
      };
    };
  };

  config = lib.mkIf config.screen-saver.enable {
    environment.systemPackages = with pkgs; [
      chrome-controller
      xprintidle
    ];

    systemd.timers."screen-saver" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:*:00";
        Unit = "screen-saver.service";
      };
    };

    systemd.services."screen-saver" = {
      enable = true;
      path = [ pkgs.xprintidle pkgs.chrome-controller pkgs.pipewire ];
      script =
        let
          urlsStr = lib.strings.concatMapStringsSep " " (x: "\"${x}\"") config.screen-saver.urls;
          urlsLen = builtins.toString (builtins.length config.screen-saver.urls);
        in
        ''
          URL_LOOP_ARR=(${urlsStr})
          URL_LOOP_LEN=${urlsLen}

          STATE_FILE=/tmp/$USER-:0-screensaver.txt
          MAX_IDLE=600

          ####################################################################
          # Check the current screen idle time
          ####################################################################
          IDLE_TIME_MS=$(DISPLAY=:0 xprintidle)
          IDLE_TIME=$((IDLE_TIME_MS/1000))
          echo "Idle Time: $IDLE_TIME"

          ####################################################################
          # Check if audio is playing by grep'ing pw-cli for output streams
          # This serves as a shorthand for whether a video is being watched
          ####################################################################
          set +e
          PIPEWIRE_REMOTE=/run/user/1001/pipewire-0 pw-cli ls Node | grep "Stream/Output/Audio"
          AUDIO_PLAYING=$?
          set -e
          echo "Audio Playing: $AUDIO_PLAYING (0 for yes, 1 for no)"

          ####################################################################
          # If the idle time is greater than the maximum and there are no
          # audio streams actively playing
          ####################################################################
          if [ $IDLE_TIME -gt $MAX_IDLE ] && [ $AUDIO_PLAYING -eq 1 ]; then
            echo "Screen saver conditions met"
            # Exit if we are in full screen
            chromectrl exit-fullscreen

            ##################################################################
            # Retrieve or initialize URL index
            ##################################################################
            echo "Obtaining index"
            if [ ! -f $STATE_FILE ]; then
              URL_IDX=0
            else
              URL_IDX=$(cat $STATE_FILE)
              URL_IDX=$((URL_IDX+1))

              if [ $URL_IDX -ge $URL_LOOP_LEN ]; then
                echo "URL index wrapped"
                URL_IDX=0
              fi
            fi
            echo "Next index: $URL_IDX"

            ##################################################################
            # Set focus to the next URL and save the index
            ##################################################################
            NEXT_URL=''${URL_LOOP_ARR[$URL_IDX]}
            echo "Next URL: $NEXT_URL"
            chromectrl focus-tab "''${NEXT_URL}"
            echo $URL_IDX > $STATE_FILE
          else
            echo "Screen saver conditions not met, skipping"
          fi
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "display";
      };
    };
  };
}
