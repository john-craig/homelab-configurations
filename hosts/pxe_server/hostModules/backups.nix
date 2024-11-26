{ pkgs, lib, config, ... }: {
  options = {
    backups.enable = lib.mkEnableOption "backup services";
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
    lib.mkIf config.backups.enable {
      environment.systemPackages = with pkgs; [
        rsync
        s3cmd
        gnupg
        curl
        pinentry
      ];

      # Required for GnuPG
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      # Daily Backup
      systemd.timers."daily-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 00:00:00";
          Unit = "daily-backup.service";
        };
      };

      # Weekly Backup
      systemd.timers."weekly-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun *-*-* 00:30:00";
          Unit = "weekly-backup.service";
        };
      };

      # Monthly Backup
      systemd.timers."monthly-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-15 01:00:00";
          Unit = "monthly-backup.service";
        };
      };

      # Offsite Backup
      systemd.timers."offsite-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Wed *-*-* 01:30:00";
          Unit = "offsite-backup.service";
        };
      };

      systemd.services = (mkBackupService "daily-backup" {
        enable = true;
        script =
          let
            rsync_cmd = "${pkgs.rsync}/bin/rsync -ravP -e '${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -F /sec/openssh/pxe_server/service/.ssh/config' --rsync-path='sudo rsync'";
          in
          ''
            # Exit if there is an ongoing offline backup
            [[ -f /var/run/offline-backup/backup.pid ]] && exit 0

            ${rsync_cmd} homeserver1:/srv/container/ /srv/backup/daily/homeserver1/srv/container
            ${rsync_cmd} homeserver1:/srv/documents/ /srv/backup/daily/homeserver1/srv/documents
          '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      }) // (mkBackupService "weekly-backup" {
        enable = true;
        script = ''
          # Exit if there is an ongoing offline backup
          [[ -f /var/run/offline-backup/backup.pid ]] && exit 0

          ${pkgs.rsync}/bin/rsync --delete -ravP /srv/backup/daily/ /srv/backup/weekly
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      }) // (mkBackupService "monthly-backup" {
        enable = true;
        script = ''
          # Exit if there is an ongoing offline backup
          [[ -f /var/run/offline-backup/backup.pid ]] && exit 0

          ${pkgs.rsync}/bin/rsync --delete -ravP /srv/backup/weekly/ /srv/backup/monthly
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      }) // (mkBackupService "offsite-backup" {
        enable = true;
        path = [ pkgs.gzip pkgs.gnutar pkgs.gnupg pkgs.s3cmd ];
        script =
          ''
            # Create a /var/run directory, if it doesn't already exist
            [[ ! -d /var/run/offline-backup/ ]] && mkdir /var/run/offline-backup/

            # Exit if there is still an ongoing backup
            [[ -f /var/run/offline-backup/backup.pid ]] && exit 0

            # Set our lock
            echo $$ > /var/run/offline-backup/backup.pid

            # Read the current backup index, creating it if it doesn't exist
            [[ ! -f /var/run/offline-backup/backup.idx ]] && echo "0" > /var/run/offline-backup/backup.idx

            # Start the backup
            tar -czf - /srv/ | gpg --encrypt --always-trust --recipient offsite-backup --homedir /sec/gnupg/pxe_server/service/.gnupg | s3cmd --config=/sec/s3cmd/pxe_server/service/.s3cfg --multipart-chunk-size-mb=500 put - s3://chiliahedron-offsite-backups/in-progress.tar.gz.gpg
            
            s3cmd --config=/sec/s3cmd/pxe_server/service/.s3cfg mv s3://chiliahedron-offsite-backups/in-progress.tar.gz.gpg s3://chiliahedron-offsite-backups/backup.tar.gz.gpg
          '';
        postStop =
          ''
            # Remove GNU's lock
            rm -f /sec/gnupg/pxe_server/service/.gnupg/public-keys.d/pubring.db.lock || true

            # Remove our lock
            rm /var/run/offline-backup/backup.pid
          '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      });
    };
}
