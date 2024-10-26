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
      gnugrep
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
      path = [ pkgs.xprintidle pkgs.chrome-controller pkgs.pipewire pkgs.gnugrep ];
      script =
        let
          urlsStr = lib.strings.concatMapStringsSep " " (x: "\"${x}\"") config.screen-saver.urls;
          urlsLen = builtins.toString (builtins.length config.screen-saver.urls);
        in
        ''
          URL_LOOP_ARR=(${urlsStr})
          URL_LOOP_LEN=${urlsLen}

          STATE_DIR=/tmp/$USER-:0-screensaver

          STATUS_FILE=$STATE_DIR/status.txt
          INDEX_FILE=$STATE_DIR/index.txt
          URL_FILE=$STATE_DIR/saved_url.txt
          FULLSCREEN_FILE=$STATE_DIR/fullscreen.txt

          MAX_IDLE=600

          ####################################################################
          # Check the current screen idle time
          ####################################################################
          IDLE_TIME_MS=$(DISPLAY=:0 xprintidle)
          IDLE_TIME=$((IDLE_TIME_MS/1000))
          echo "Idle Time: $IDLE_TIME"

          ####################################################################
          # Check if a video is currently being watched
          ####################################################################
          set +e
          VIDEO_PLAYING=$(chromectrl is-video-playing)
          set -e
          echo "Video Playing: $VIDEO_PLAYING"

          ####################################################################
          # If the idle time is greater than the maximum and there are no
          # videos currently playing
          ####################################################################
          if [ $IDLE_TIME -gt $MAX_IDLE ] && [ "$VIDEO_PLAYING" = "False" ]; then
            echo "Screen saver conditions met"

            mkdir -p $STATE_DIR

            if [ ! -f $STATUS_FILE ]; then
              echo "Stopped" > $STATUS_FILE
            fi

            if grep -qE 'Stopped' $STATUS_FILE; then
              # Save information about browser status
              chromectrl get-focused-tab > $URL_FILE
              chromectrl is-video-fullscreen > $FULLSCREEN_FILE
              echo "Running" > $STATUS_FILE
            fi

            # Exit if we are in full screen
            chromectrl exit-fullscreen

            ##################################################################
            # Retrieve or initialize URL index
            ##################################################################
            echo "Obtaining index"
            if [ ! -f $INDEX_FILE ]; then
              URL_IDX=0
            else
              URL_IDX=$(cat $INDEX_FILE)
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
            echo $URL_IDX > $INDEX_FILE
          else
            echo "Screen saver conditions not met, skipping"

            echo "Stopped" > $STATUS_FILE
          fi
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "display";
      };
    };
  };
}
