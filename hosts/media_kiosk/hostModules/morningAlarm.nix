{ pkgs, lib, config, ... }: {
  options = {
    morningAlarm = {
      enable = lib.mkEnableOption "configuration for Morning Alarm";

      urls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = lib.mdDoc ''
          The URLs of the pages to loop over as the morning alarm.
        '';
      };
    };
  };

  config = lib.mkIf config.morningAlarm.enable {
    environment.systemPackages = with pkgs; [
      chrome-controller
    ];

    systemd.timers."morningAlarm-start" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon,Tue,Wed,Thu,Fri *-*-* 06:00:00";
        Unit = "morningAlarm-start.service";
      };
    };

    systemd.timers."morningAlarm-stop" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon,Tue,Wed,Thu,Fri *-*-* 06:30:00";
        Unit = "morningAlarm-stop.service";
      };
    };

    systemd.services."morningAlarm-start" = {
      enable = true;
      path = [ pkgs.chrome-controller ];
      script =
        let
          urlsStr = lib.strings.concatMapStringsSep " " (x: "\"${x}\"") config.morningAlarm.urls;
          urlsLen = builtins.toString (builtins.length config.morningAlarm.urls);
        in
        ''
          URL_LOOP_ARR=(${urlsStr})
          URL_LOOP_LEN=${urlsLen}

          STATE_DIR=/tmp/$USER-morningalarm
          INDEX_FILE=$STATE_DIR/index.txt

          mkdir -p $STATE_DIR

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

          chromectrl open-tab $NEXT_URL

          echo $URL_IDX > $INDEX_FILE
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "display";
      };
    };


    systemd.services."morningAlarm-stop" = {
      enable = true;
      path = [ pkgs.chrome-controller ];
      script =
        let
          urlsStr = lib.strings.concatMapStringsSep " " (x: "\"${x}\"") config.morningAlarm.urls;
          urlsLen = builtins.toString (builtins.length config.morningAlarm.urls);
        in
        ''
          URL_LOOP_ARR=(${urlsStr})
          URL_LOOP_LEN=${urlsLen}

          STATE_DIR=/tmp/$USER-morningalarm
          INDEX_FILE=$STATE_DIR/index.txt

          mkdir -p $STATE_DIR

          ##################################################################
          # Retrieve or initialize URL index
          ##################################################################
          echo "Obtaining index"
          if [ ! -f $INDEX_FILE ]; then
            echo "Index file not found, exiting"
            exit 0
          fi
          
          URL_IDX=$(cat $INDEX_FILE)
          echo "Next index: $URL_IDX"

          ##################################################################
          # Set focus to the next URL and save the index
          ##################################################################
          NEXT_URL=''${URL_LOOP_ARR[$URL_IDX]}
          echo "Next URL: $NEXT_URL"

          chromectrl close-tab $NEXT_URL
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "display";
      };
    };
  };
}
