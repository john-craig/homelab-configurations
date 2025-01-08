{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./automatedBackups
      ./disasterRecovery
      ./voiceAssistant
      ./userProfiles
    ];

  # Set your time zone.
  time.timeZone = "America/New_York";
}
