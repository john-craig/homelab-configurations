{ pkgs, lib, config, ... }: {
  options = {
    personalSite = {
      enable = lib.mkEnableOption "configuration for Person Website";
    };
  };

  config = lib.mkIf config.personalSite.enable {
    environment.systemPackages = with pkgs; [
      dev-journal-builder
    ];

    systemd.timers."rebuild-personal-site" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 00:00:00";
        Unit = "rebuild-personal-site.service";
      };
    };


    systemd.services."rebuild-personal-site" = {
      enable = true;
      path = [ pkgs.dev-journal-builder pkgs.git pkgs.podman ];
      script = ''
        # Wipe out the current contents
        rm -rf /srv/container/gatsby-dev-blog/blog/*
        rm -rf /srv/container/gatsby-dev-blog/blog/.git

        # Clone down the `publish` branch of the content
        cd /srv/container/gatsby-dev-blog/blog && git clone -b publish https://gitea.chiliahedron.wtf/john-craig/dev-blog-content.git .
        rm -f /srv/container/gatsby-dev-blog/blog/README.md

        # Set up the journal
        mkdir /srv/container/gatsby-dev-blog/blog/journal
        dev-journal-builder /srv/container/gatsby-dev-blog/blog/journal /srv/documents/by_category/vault

        # Rebuild
        podman pull registry.chiliahedron.wtf/john-craig/gatsby-dev-blog:latest
        podman restart dev-blog-dev-blog
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };
}
