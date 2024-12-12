{ pkgs, lib, config, ... }: {
  options = {
    offsiteBackups = {
      enable = lib.mkEnableOption "Offsite backup services";

      gnupgHomeDir = lib.mkOption {
        description = "Path to GnuPG home directory";
        type = lib.types.str;
      };

      s3cmdConfigFile = lib.mkOption {
        description = "Path to s3cmd configuration file";
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf config.offsiteBackups.enable {
    environment.systemPackages = with pkgs; [
      s3cmd
      gnupg
      gzip
      gnutar
      curl
      pinentry
    ];

    # Required for GnuPG
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # Offsite Backup
    systemd.timers."offsite-backup" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Wed *-*-* 01:30:00";
        Unit = "offsite-backup.service";
      };
    };

    notifiedServices.services = {
      "offsite-backup" = {
        enable = true;
        path = [ pkgs.gzip pkgs.gnutar pkgs.gnupg pkgs.s3cmd ];
        script =
          ''
            # Create a /var/run directory, if it doesn't already exist
            [[ ! -d /var/run/offsite-backup/ ]] && mkdir /var/run/offsite-backup/

            # Exit if there is still an ongoing backup
            [[ -f /var/run/offsite-backup/backup.pid ]] && exit 0

            # Set our lock
            echo $$ > /var/run/offsite-backup/backup.pid

            # Read the current backup index, creating it if it doesn't exist
            [[ ! -f /var/run/offsite-backup/backup.idx ]] && echo "0" > /var/run/offsite-backup/backup.idx

            # Start the backup
            tar -czf - /srv/ | gpg --encrypt --always-trust --recipient offsite-backup --homedir ${config.offsiteBackups.gnupgHomeDir} | s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} --multipart-chunk-size-mb=500 put - s3://chiliahedron-offsite-backups/in-progress.tar.gz.gpg
            
            s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} mv s3://chiliahedron-offsite-backups/in-progress.tar.gz.gpg s3://chiliahedron-offsite-backups/backup.tar.gz.gpg
          '';
        postStop =
          ''
            # Remove GNU's lock
            rm -f ${config.offsiteBackups.gnupgHomeDir}/public-keys.d/pubring.db.lock || true

            # Remove our lock
            rm /var/run/offsite-backup/backup.pid
          '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    };
  };
}
