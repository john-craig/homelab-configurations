{ pkgs, lib, config, ... }: {
  options = {
    link-archiver = {
      enable = lib.mkEnableOption "configuration for Link Archiver";
    };
  };

  config = lib.mkIf config.link-archiver.enable {
    environment.systemPackages = with pkgs; [
      obsidian-link-archiver
    ];

    # System Daemon Timers
    systemd.timers."archive-obsidian-links" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 23:00:00";
        Unit = "archive-obsidian-links.service";
      };
    };

    systemd.services."archive-obsidian-links" = {
      enable = true;
      script = ''
        # Perform the archive
        ${pkgs.obsidian-link-archiver}/bin/obsidian-link-archiver /srv/documents/by_category/vault/notes
        ${pkgs.obsidian-link-archiver}/bin/obsidian-link-archiver /srv/documents/by_category/vault/projects
        
        # Restart archivebox to kill off erroneous Chrome processes
        ${pkgs.podman}/bin/podman restart archivebox-archivebox
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "service";
      };
    };

  };
}
