# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "pizero1";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    smartmontools
    git

    python3
    # Uncomment the below if you need python3 with specific packages 
    #
    # (python3.withPackages(ps: with ps; [
    #   requests
    #   ...
    # ]))
  ];

  services.openssh = {
    enable = true;
    
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users."service" = {
    isNormalUser = true;
    home = "/home/service";
    extraGroups = [ "wheel" ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCb2oTTiI5D/Js2ZYHyruuECUUFNYrjErBOEFfvlxaqn4Q5w81PwHtMIwgbToNbCqglESa3v1F8i2isuTvoexauCr8CEqBO4xOEZAimv38kqQhORyHDoRJvFTrXnnkSr82jmK+NuTvM0M8YPFjIW2vPPTS8ubjINUOOsucVm0duK//8/2zw23cE87HE4fsy8TjvFrDFWYZdVni2Op7mYZ95/qjAmhNmtj9rkJ+Z111rg78rFf5Utp3tOMvfXiGS3OO24Z8YtCzlMYi1EIJMvps4/ENTT0X7F3GZXu3gv2WU662tPHhmBBYbVQXY2+GEhCG1VguL7BSRGAsvcTjPriMQVRvzpFuY5cR8feM38O2DTV1L87szLuOjwCusfrvtR0jWlpURGfHuxF8CtAldBopfBqfuNamwfVGaMR9T3mbbxC5CcdZh3vaZ1/6D9AuK80A9tYm5wqUHaROaNidOxLsLNto8G2BW+ABCFeQ81kUkGU4byhhsxLamYshtN6MMEN0=" 
    ];
  };

  security.sudo.extraRules = [
    { 
      users = [ "service" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

