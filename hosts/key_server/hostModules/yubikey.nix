{ config, lib, pkgs, ... }:
let 
  deviceUUID = "e893ee82-c8c1-4edc-a747-1e84ed388b58";
in 
{
   environment.systemPackages = with pkgs; [
    openssl
    libfido2
    yubikey-manager
   ];

  # Required for Yubikey and GnuPG
  services.pcscd.enable = true;



  systemd.services = {
    "secure-partition-reunlock" = {
      enable = true;
      script = ''
        # Restart the cryptsetup service to ensure it can access the Yubikey
        ${pkgs.systemd}/bin/systemctl restart systemd-cryptsetup@crypt0.service
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    "cryptsetup@" = {
      serviceConfig = {
        # TODO: add a notifier to indicate the Yubikey is ready to unlock
        ExecStartPre = "";
      };
      onFailure = [
        # TODO: add some kind of notifier of failure here
      ];
    };
  };

  environment.etc."crypttab".text = ''
    crypt0            UUID=${deviceUUID} - nofail,fido2-device=auto,token-timeout=0,headless=true
  '';

  fileSystems."/sec" = {
    device = "/dev/mapper/crypt0";
    fsType = "btrfs";
    options = [ "nofail" ];
  };

  # Set up the udev rules for Yubikey hidraw0
  services.udev.extraRules = ''
    # Trigger systemd-cryptsetup service when Yubikey or secure partition are added
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0402", TAG+="systemd", ENV{SYSTEMD_WANTS}+="secure-partition-reunlock.service"
    ACTION=="add", KERNEL=="sd*", ENV{ID_FS_UUID}=="${deviceUUID}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="secure-partition-reunlock.service"

    # Mount the secure partition after decryption
    ACTION=="add", KERNEL=="dm-*", ENV{DM_NAME}=="crypt0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="sec.mount"
  '';
}