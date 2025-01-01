{ pkgs, lib, config, ... }: {
  options = {
    morningAlarm = {
      enable = lib.mkEnableOption "configuration for Morning Alarm";

      url = lib.mkOption {
        type = lib.types.str;
        description = lib.mdDoc ''
          The URL of the page to open as the morning alarm.
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
        ''
          chromectrl open-tab ${config.morningAlarm.url}
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
        ''
          chromectrl close-tab "${config.morningAlarm.url}"
        '';
      serviceConfig = {
        Type = "oneshot";
        User = "display";
      };
    };
  };
}
