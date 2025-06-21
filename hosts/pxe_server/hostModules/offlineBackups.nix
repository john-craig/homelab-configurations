{ pkgs, lib, config, ... }: 
let
  inherit (lib) mapAttrs' nameValuePair;
  varPath = "/var/run/offline-backup";
  pidFile = "${varPath}/backup.pid";
in {
  options = {
    offlineBackups = {
      enable = lib.mkEnableOption "offline backup services";

      backupPath = lib.mkOption {
        type = lib.types.str;
        default = "/srv";
        description = "Path to backup";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/mnt";
        description = "Path to mount offline devices";
      };

      offlineDevices = lib.mkOption {
        type = lib.types.listOf lib.types.str; # Define it as a list of strings
        default = [ ]; # Default to an empty list
        description = "UUIDs of devices to which offline backups should be copied.";
      };
    };
  };

  config =
    lib.mkIf config.offlineBackups.enable {
      environment.systemPackages = [
        pkgs.util-linux
        pkgs.gnugrep
        pkgs.cryptsetup
        pkgs.rsync
      ];

      systemd.tmpfiles.rules = [
        "d ${config.offlineBackups.mountPoint}  700 root root"
        "d ${varPath}  700 root root"
      ];

      systemd.services = builtins.listToAttrs (map (uuid:
        let
          shortUUID = builtins.elemAt (lib.strings.splitString "-" uuid) 0;
        in nameValuePair "offline-backup-trigger-${shortUUID}" {
          description = "Offline backup trigger for device ${shortUUID}";
          wantedBy = [ "systemd-cryptsetup@cryptX.${shortUUID}.service" ];
          after = [ "systemd-cryptsetup@cryptX.${shortUUID}.service" ];
          bindsTo = [ "systemd-cryptsetup@cryptX.${shortUUID}.service" ];

          script = ''
            ${pkgs.mount}/bin/mount /dev/mapper/cryptX.${shortUUID} ${config.offlineBackups.mountPoint}
            ${pkgs.systemd}/bin/systemctl start offline-backup.service
          '';

          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
        }
      ) config.offlineBackups.offlineDevices);

      notifiedServices.services = {
        "offline-backup" = {
          enable = true;

          script =
            let
              rsyncCmd = "${pkgs.rsync}/bin/rsync -ravPH";
            in
            ''
              echo "Starting offline backup to ${config.offlineBackups.mountPoint}"

              # Exit if there is an ongoing offline backup
              [[ -f ${pidFile} ]] && exit 0

              echo $$ > ${pidFile}
              ${rsyncCmd} ${config.offlineBackups.backupPath}/ ${config.offlineBackups.mountPoint}   
              echo "Offline backup completed successfully"
            '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };

          postStop = ''
            ${pkgs.umount}/bin/umount ${config.offlineBackups.mountPoint}
            ${pkgs.systemd}/bin/systemctl stop systemd-cryptsetup@cryptX.*.service
            rm -f ${pidFile}
          '';
        };
      };

      services.udev.extraRules = lib.strings.concatMapStrings
        (deviceUUID:
          let
            shortUUID = builtins.elemAt (lib.strings.splitString "-" deviceUUID) 0;
          in
          ''
            ACTION=="add", KERNEL=="sd*", ENV{ID_FS_UUID}=="${deviceUUID}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="systemd-cryptsetup@cryptX.${shortUUID}.service"
          '')
        config.offlineBackups.offlineDevices;

      environment.etc."crypttab".text = lib.strings.concatMapStrings
        (deviceUUID:
          let
            shortUUID = builtins.elemAt (lib.strings.splitString "-" deviceUUID) 0;
          in
          ''
            cryptX.${shortUUID}        UUID=${deviceUUID}    /root/cryptsetup/crypt0/keyfile.bin nofail,noauto
          '')
        config.offlineBackups.offlineDevices;
    };
}
