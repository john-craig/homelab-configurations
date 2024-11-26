{ pkgs, lib, config, ... }: {
  options = {
    offsiteBackups.enable = lib.mkEnableOption "backup services";
  };

  config =
    let
      mkBackupService = backupName: backupDef: (
        {
          "${backupName}" = (
            backupDef // {
              onSuccess = [ "${backupName}-success-notifier.service" ];
              onFailure = [ "${backupName}-failure-notifier.service" ];
            }
          );
          "${backupName}-success-notifier" = {
            enable = true;
            path = [ pkgs.curl ];
            script = ''
              GOTIFY_TOKEN=$(cat /sec/gotify/pxe_server/service/backup-notifier-token.txt)
              DISPLAY_DATE=$(date)
              curl -s -S --data '{"message": "'"${backupName} succeeded on $DISPLAY_DATE"'", "title": "'"${backupName} Succeeded"'", "priority":'"1"', "extras": {"client::display": {"contentType": "text/markdown"}}}' -H 'Content-Type: application/json' "https://gotify.chiliahedron.wtf/message?token=$GOTIFY_TOKEN"
            '';
            serviceConfig = {
              Type = "oneshot";
              User = "root";
            };
          };
          "${backupName}-failure-notifier" = {
            enable = true;
            path = [ pkgs.curl ];
            script = ''
              GOTIFY_TOKEN=$(cat /sec/gotify/pxe_server/service/backup-notifier-token.txt)
              DISPLAY_DATE=$(date)
              curl -s -S --data '{"message": "'"${backupName} failed on $DISPLAY_DATE"'", "title": "'"${backupName} Failed"'", "priority":'"10"', "extras": {"client::display": {"contentType": "text/markdown"}}}' -H 'Content-Type: application/json' "https://gotify.chiliahedron.wtf/message?token=$GOTIFY_TOKEN"
            '';
            serviceConfig = {
              Type = "oneshot";
              User = "root";
            };
          };
        }
      );
    in
    lib.mkIf config.offsiteBackups.enable {
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

      systemd.services = (mkBackupService "offsite-backup" {
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
            tar -czf - /srv/ | gpg --encrypt --always-trust --recipient offsite-backup --homedir /sec/gnupg/pxe_server/service/.gnupg | s3cmd --config=/sec/s3cmd/pxe_server/service/.s3cfg --multipart-chunk-size-mb=500 put - s3://chiliahedron-offsite-backups/in-progress.tar.gz.gpg
            
            s3cmd --config=/sec/s3cmd/pxe_server/service/.s3cfg mv s3://chiliahedron-offsite-backups/in-progress.tar.gz.gpg s3://chiliahedron-offsite-backups/backup.tar.gz.gpg
          '';
        postStop =
          ''
            # Remove GNU's lock
            rm -f /sec/gnupg/pxe_server/service/.gnupg/public-keys.d/pubring.db.lock || true

            # Remove our lock
            rm /var/run/offsite-backup/backup.pid
          '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      });
    };
}
