{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./automatedBackups
      ./disasterRecovery
      ./resourceCache
      ./garbageCollector
      ./voiceAssistant
      ./userProfiles
    ];

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Default packages
  environment.systemPackages = with pkgs; [
    dig
    wget
    curl
    git
    screen
    inetutils
    usbutils
    btrfs-progs
    python3
    nano
    gnupg
    cryptsetup
    htop
  ];

  # Default SSH daemon configuration
  services.openssh = {
    enable = true;
    allowSFTP = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  resourceCache = {
    enable = true;

    role = lib.mkDefault "client";
    credentials.privateKey = config.sops.secrets."openssh/root/cacher".path;
    resources = {
      nix.enable = true;
    };
  };
}
