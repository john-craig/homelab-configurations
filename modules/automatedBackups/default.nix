{ pkgs, lib, config, ... }:
let
  mkNotifierScript = title: message: tokenPath:
    ''
      GOTIFY_TOKEN=$(cat ${tokenPath})
      DISPLAY_DATE=$(date)
      curl -s -S --data '{"message": "'"${message}"'", "title": "'"${title}"'", "priority":'"1"', "extras": {"client::display": {"contentType": "text/markdown"}}}' -H 'Content-Type: application/json' "https://gotify.chiliahedron.wtf/message?token=$GOTIFY_TOKEN"
    '';

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
        script = mkNotifierScript "${backupName} Succeeded"
          "${backupName} succeeded on $DISPLAY_DATE"
          "/sec/gotify/pxe_server/service/backup-notifier-token.txt";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
      "${backupName}-failure-notifier" = {
        enable = true;
        path = [ pkgs.curl ];
        script = mkNotifierScript "${backupName} Failed"
          "${backupName} failed on $DISPLAY_DATE"
          "/sec/gotify/pxe_server/service/backup-notifier-token.txt";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    });
in
{
  options = {
    automatedBackups = {
      enable = lib.mkEnableOption "configuration for Caching and Disaster Recovery";

      role =
        let
          # Define the allowed values as a list
          allowedValues = [ "client" "server" ];
        in
        lib.mkOption {
          type = lib.types.str;
          default = "client"; # default value
          description = "Defines whether the configuration is for the client, server.";
        };

      backupPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str; # Define it as a list of strings
        default = [ ]; # Default to an empty list
        description = "A list of paths on a client host that are intended to be backed up.";
      };

      backupHosts = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "An attribute set of paths on each host to be backed up.";
      };
    };
  };

  config = (lib.mkIf config.automatedBackups.enable) {
    #############################################
    # Client configurations
    #############################################
    users = lib.mkIf (config.automatedBackups.role == "client") {
      groups."backup" = { };

      users."backup" = {
        group = "backup";
        isNormalUser = true;
        initialPassword = null;

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBWQJo/oNHKCibeuNkGAWfn5oeqTQlwTbTryg8Xk7dDM"
        ];
      };
    };

    systemd.tmpfiles.rules = lib.mkIf (config.automatedBackups.role == "client")
      (lib.lists.foldl
        (acc: backupPath:
          # Set access list to backup path
          acc ++ [
            # "A+ ${backupPath} -    -    -     -           m::rx"
            "A+ ${backupPath} -    -    -     -           u:backup:rx"
          ]
        ) [ ]
        config.automatedBackups.backupPaths);

    #############################################
    # Server configurations
    #############################################
    environment.systemPackages = with pkgs; lib.mkIf (config.automatedBackups.role == "server") [
      rsync
      curl
    ];

    # Required for GnuPG
    programs.gnupg.agent = lib.mkIf (config.automatedBackups.role == "server") {
      enable = true;
      enableSSHSupport = true;
    };

    systemd.timers = lib.mkIf (config.automatedBackups.role == "server") {
      # Daily Backup
      "daily-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 00:00:00";
          Unit = "daily-backup.service";
        };
      };

      # Weekly Backup
      "weekly-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun *-*-* 00:30:00";
          Unit = "weekly-backup.service";
        };
      };

      # Monthly Backup
      "monthly-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-15 01:00:00";
          Unit = "monthly-backup.service";
        };
      };
    };

    systemd.services = lib.mkIf (config.automatedBackups.role == "server")
      ((mkBackupService "daily-backup" {
        enable = true;
        script =
          let
            backupId = "/sec/openssh/pxe_server/backup/.ssh/backup";
            rsyncCmd = "${pkgs.rsync}/bin/rsync -ravP -e '${pkgs.openssh}/bin/ssh -i ${backupId} -o StrictHostKeyChecking=no'";

            # We do this to allowed us to ignore files for which we do not have read permissions
            rsyncEnd = "$(case \"$?\" in 0|23) true ;; *) $?; esac)";

            backupCmds = lib.attrsets.foldlAttrs
              (acc: backupHost: backupPaths:
                acc + lib.strings.concatMapStrings
                  (backupPath: ''
                    ${rsyncCmd} --link-dest /srv/backup/weekly/${backupHost}/${backupPath} backup@${backupHost}:${backupPath}/ /srv/backup/daily/${backupHost}/${backupPath} || ${rsyncEnd}
                  '')
                  backupPaths
              ) ""
              config.automatedBackups.backupHosts;
          in
          ''
            # Exit if there is an ongoing offline backup
            [[ -f /var/run/offline-backup/backup.pid ]] && exit 0

            ${backupCmds}
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

          ${pkgs.rsync}/bin/rsync --link-dest /srv/backup/monthly --delete -ravP /srv/backup/daily/ /srv/backup/weekly
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

          ${pkgs.rsync}/bin/rsync --link-dest /srv/backup/monthly --delete -ravP /srv/backup/weekly/ /srv/backup/monthly
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      }));
  };
}
