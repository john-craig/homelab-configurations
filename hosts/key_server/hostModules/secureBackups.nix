{ pkgs, lib, config, ... }: let
  backupSrc = "/sec";
  mountPoint = "/mnt";
in {
  options = {
    secureBackups = {
      enable = lib.mkEnableOption "secure backup services";

      secureDevices = lib.mkOption {
        type = lib.types.listOf lib.types.str; # Define it as a list of strings
        default = [ ]; # Default to an empty list
        description = "UUIDs of devices to which secure backups should be copied.";
      };
    };
  };

  config =
    lib.mkIf config.secureBackups.enable {
      environment.systemPackages = [
        pkgs.util-linux
        pkgs.gnugrep
        pkgs.cryptsetup
        pkgs.rsync
      ];

      systemd.tmpfiles.rules = [
        "d ${mountPoint}  700 root root"
      ];

      notifiedServices.services = {
        "secure-backup" = {
          enable = true;
          environment = {
            SECURE_UUIDS = lib.concatStringsSep " " config.secureBackups.secureDevices;
          };
          script =
            let
              rsyncCmd = "${pkgs.rsync}/bin/rsync -ravPH";
            in
            ''
              # Check if mount point is already mounted
              if ${pkgs.mount}/bin/mountpoint -q ${mountPoint}; then
                echo "Mount point ${mountPoint} is already mounted, exiting."
                exit 0
              fi

              # Check if secure devices are specified
              for uuid in $SECURE_UUIDS; do
                if [ -e "/dev/disk/by-uuid/$uuid" ]; then
                  echo "Found secure device with UUID: $uuid"
                  DEVICE_PATH="/dev/disk/by-uuid/$uuid"
                fi
              done

              # If no secure device was found, exit
              if [ -z "$DEVICE_PATH" ]; then
                echo "No secure devices found, exiting."
                exit 0
              fi

              # Mount the secure device
              echo "Mounting device $DEVICE_PATH to ${mountPoint}"
              ${pkgs.mount}/bin/mount $DEVICE_PATH ${mountPoint}

              echo "Starting backup to ${mountPoint}"
              ${rsyncCmd} ${backupSrc}/ ${mountPoint}

              echo "Backup completed successfully."   
              ${pkgs.umount}/bin/umount ${mountPoint}
            '';

          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
        };
      };

      services.udev.extraRules = lib.strings.concatMapStrings
        (deviceUUID:
          ''
            ACTION=="add",KERNEL=="sd*",ENV{ID_FS_UUID}=="${deviceUUID}",TAG+="systemd",ENV{SYSTEMD_WANTS}+="secure-backup.service"
          '')
        config.secureBackups.secureDevices;

    };
}