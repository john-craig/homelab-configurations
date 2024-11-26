{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./automatedBackups
      ./disasterRecovery
      ./voiceAssistant
    ];

  # Set your time zone.
  time.timeZone = "America/New_York";
}
