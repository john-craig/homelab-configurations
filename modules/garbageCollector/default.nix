{ pkgs, lib, config, user-envs, ... }: {
  options = {
    garbageCollect = {
      enable = lib.mkEnableOption "Periodic NixOS Garbage Collection";
    };
  };

  config = lib.mkIf config.garbageCollect.enable {
    systemd.timers = {
      "collect-garbage" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Fri *-*-* 00:00:00";
          Unit = "collect-garbage.service";
        };
      };
    };

    systemd.services = {
      "collect-garbage" = {
        enable = true;
        script =
          ''
            ${pkgs.nix}/bin/nix-collect-garbage -d;
          '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    };
  };
}
