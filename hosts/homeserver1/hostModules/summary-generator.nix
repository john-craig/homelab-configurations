{ pkgs, lib, config, ... }: {
  options = {
    summary-generator = {
      enable = lib.mkEnableOption "configuration for Summary Generator";
    };
  };

  config = lib.mkIf config.summary-generator.enable {
    environment.systemPackages = with pkgs; [
      status-page-generator
    ];

    systemd.timers."generate-project-summary" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/10";
        Unit = "generate-project-summary.service";
      };
    };

    systemd.services."generate-project-summary" = {
      enable = true;
      script = ''
        # Regenerate the files
        ${pkgs.status-page-generator}/bin/status-generator /srv/documents/by_category/vault /srv/container/status-page
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

  };
}