{ pkgs, lib, config, ... }: {
  options = {
    offsiteBackups = {
      enable = lib.mkEnableOption "Offsite backup services";

      s3Bucket = lib.mkOption {
        description = "Name of the s3 bucket to upload to";
        type = lib.types.str;
      };

      s3cmdConfigFile = lib.mkOption {
        description = "Path to s3cmd configuration file";
        type = lib.types.str;
      };

      gnupgRecipient = lib.mkOption {
        description = "Recipient for encryption";
        type = lib.types.str;
      };

      gnupgHomeDir = lib.mkOption {
        description = "Path to GnuPG home directory";
        type = lib.types.str;
      };

      backupProfiles = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            prefix = lib.mkOption {
              type = lib.types.str;
              description = "Prefix to use for backup files";
            };

            path = lib.mkOption {
              type = lib.types.str;
              description = "Path to backup";
            };
          };
        });
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
    ] ++ builtins.map
      (
        backupProfile: (
          pkgs.writeShellScriptBin "offsite-backup-restore-${backupProfile.prefix}" ''
            #!/bin/bash
            BUCKET_NAME="${config.offsiteBackups.s3Bucket}"
            UPLOAD_STEM="${backupProfile.prefix}"
            RESTORE_PATH=$1
            WORK_DIR="''${1:-/tmp}"

            # Determine the latest upload
            LATEST_UPLOAD=$(s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} \
              ls ${config.offsiteBackups.s3Bucket} | \
              grep success | awk '{ print $4 }' | \
              cut -d '.' -f 2 | sort | tail -n 1)
          
            pushd $WORK_DIR
              # Obtain each of the partial archives
              s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} \
                --multipart-chunk-size-mb=500 \
                get "${config.offsiteBackups.s3Bucket}/$UPLOAD_STEM.$LATEST_UPLOAD.part*" .
          
              for part in ./$UPLOAD_STEM.$LATEST_UPLOAD.part*.tar.gz.gpg; do 
                # Decrypt each partial archive one at a time
                gpg --decrypt --always-trust --recipient ${config.offsiteBackups.gnupgRecipient} \
                  --homedir ${config.offsiteBackups.gnupgHomeDir} $part > ''${part%.gpg}; 
                rm $part
              done

              # Concatenate and extract partial archives
              cat ./$UPLOAD_STEM.$LATEST_UPLOAD.part*.tar.gz | tar -xzf - -C $RESTORE_PATH

              # Remove partial archives
              rm ./$UPLOAD_STEM.$LATEST_UPLOAD.part*.tar.gz
            popd
          ''
        )
      )
      config.offsiteBackups.backupProfiles;

    # Required for GnuPG
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # Offsite Backup
    systemd.timers."offsite-backup" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Wed *-*-24 01:30:00";
        Unit = "offsite-backup.service";
      };
    };

    notifiedServices.services = {
      "offsite-backup" = {
        enable = true;
        path = [ pkgs.gzip pkgs.gawk pkgs.gnutar pkgs.gnupg pkgs.s3cmd ];
        script = lib.strings.concatMapStrings
          (backupProfile:
            ''
              BUCKET_NAME="${config.offsiteBackups.s3Bucket}"
              UPLOAD_STEM="${backupProfile.prefix}"
              UPLOAD_BASE="$UPLOAD_STEM.$(date +%Y-%m-%dT%H-%M-%S)"
              BACKUP_PATH="${backupProfile.path}"

              # Create a /var/run directory, if it doesn't already exist
              [[ ! -d /var/run/offsite-backup/ ]] && mkdir /var/run/offsite-backup/

              # Exit if there is still an ongoing backup
              [[ -f /var/run/offsite-backup/backup.pid ]] && exit 0

              # Set our lock
              echo $$ > /var/run/offsite-backup/backup.pid

              # Perform upload
              tar -czf - "$BACKUP_PATH" | 
              split --suffix-length=3 --numeric-suffixes \
                --bytes=5000M - "$UPLOAD_BASE.part" --filter=' \
                  gpg --encrypt --always-trust --recipient ${config.offsiteBackups.gnupgRecipient} \
                    --homedir ${config.offsiteBackups.gnupgHomeDir} | \
                  s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} \
                    --multipart-chunk-size-mb=500 \
                    --max-retries=25 \
                    put - "${config.offsiteBackups.s3Bucket}/$FILE.tar.gz.gpg"'

              date | s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} \
                put - "${config.offsiteBackups.s3Bucket}/$UPLOAD_BASE.success"

              # Remove parts  
              s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} \
                ls $BUCKET_NAME | \
              grep "$BUCKET_NAME/$UPLOAD_STEM" | grep -v $UPLOAD_BASE | \
              awk '{ print $4 }' | \
              while read FILE; do \
                s3cmd --config=${config.offsiteBackups.s3cmdConfigFile} rm $FILE; \
              done
            ''
          )
          config.offsiteBackups.backupProfiles;
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
