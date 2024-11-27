{ pkgs, lib, config, ... }: {
  options = {
    offlineBackups.enable = lib.mkEnableOption "backup services";
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
    lib.mkIf config.offlineBackups.enable {
      systemd.tmpfiles.rules = [
        "d /mnt/ext0  700 root root"
      ];

      services.udev.extraRules = ''
        ACTION=="add", KERNEL=="sd*", ENV{ID_FS_UUID}=="29380df2-3ed6-40e8-a7d2-f804ce015b32", RUN+="${pkgs.systemd}/bin/systemctl restart systemd-cryptsetup@cryptX.1.service"
      '';

      environment.etc."crypttab".text = ''
        # Data partition for offline backups
        cryptX.1          UUID=29380df2-3ed6-40e8-a7d2-f804ce015b32    /root/cryptsetup/crypt0/keyfile.bin nofail
      '';

      fileSystems."/mnt/ext0" =
        {
          device = "/dev/mapper/cryptX.1";
          fsType = "btrfs";
        };
    };
}
