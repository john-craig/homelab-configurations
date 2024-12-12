{ pkgs, lib, config, ... }: {
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
      ];

      notifiedServices.services = {
        "offline-backup" = {
          enable = true;
          script =
            let
              rsyncCmd = "${pkgs.rsync}/bin/rsync -ravPH";
            in
            ''
              # Exit if there is an ongoing offline backup
              [[ -f /var/run/offline-backup/backup.pid ]] && exit 0

              ${pkgs.mount}/bin/mount /dev/mapper/cryptX.* ${config.offlineBackups.mountPoint}
              ${rsyncCmd} ${config.offlineBackups.backupPath}/ ${config.offlineBackups.mountPoint}   
              ${pkgs.umount}/bin/umount ${config.offlineBackups.mountPoint}
            '';

          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };

          postStop = ''
            ${pkgs.systemd}/bin/systemctl stop systemd-cryptsetup@cryptX.*.service
          '';
        };
      };

      services.udev.extraRules = lib.strings.concatMapStrings
        (deviceUUID:
          let
            shortUUID = builtins.elemAt (lib.strings.splitString "-" deviceUUID) 0;
          in
          ''
            ACTION=="add", KERNEL=="sd*", ENV{ID_FS_UUID}=="${deviceUUID}", ENV{SYSTEMD_WANTS}+="systemd-cryptsetup@cryptX.${shortUUID}.service"
            ACTION=="add", KERNEL=="dm*", ATTR{dm/name}=="cryptX.${shortUUID}", ENV{SYSTEMD_WANTS}+="offline-backup.service"
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
