{ pkgs, lib, config, ... }: {
  options = {
    notifier.enable = lib.mkEnableOption "configuration for Notifier";
  };

  config = lib.mkIf config.notifier.enable {
    environment.systemPackages = with pkgs; [
      gotify-desktop
      libnotify
    ];

    home-manager.users.display = {
      home.file.".config/gotify-desktop/config.toml".text = ''
        [gotify]
        url = "wss://gotify.chiliahedron.wtf"
        token = "CRz-lyqEKaMR8Rl"
        
        [notification]
        min_priority = 1

        [action]
        # optional, run the given command for each message, with the following environment variables set: GOTIFY_MSG_PRIORITY, GOTIFY_MSG_TITLE and GOTIFY_MSG_TEXT.
        on_msg_command = "${pkgs.libnotify}/bin/notify-send '$GOTIFY_MSG_TITLE' '$GOTIFY_MSG_TEXT'"
      '';
      systemd.user.startServices = true;
      systemd.user.services."gotify-desktop" = {
        Unit = {
          Description = "Desktop notification from gotify";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.gotify-desktop}/bin/gotify-desktop";
          Restart = "on-failure";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
      services.dunst.enable = true;
    };
  };
}
