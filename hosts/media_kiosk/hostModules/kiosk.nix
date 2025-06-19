{ pkgs, lib, config, ... }: {
  options = {
    kiosk.enable = lib.mkEnableOption "configuration for Kiosk Mode";
  };

  config = lib.mkIf config.kiosk.enable {
    environment.systemPackages = with pkgs; [
      ungoogled-chromium
    ];

    home-manager.users.display.programs.chromium = {
      enable = true;
      # extensions = [ "cjpalhdlnbpafiamejdnhcphjbkeiagm" ]; # ublock origin
      extensions =
      let
        createChromiumExtensionFor = browserVersion: { id, sha256, version }:
          {
            inherit id;
            crxPath = builtins.fetchurl {
              url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${browserVersion}&x=id%3D${id}%26installsource%3Dondemand%26uc";
              name = "${id}.crx";
              inherit sha256;
            };
            inherit version;
          };
        createChromiumExtension = createChromiumExtensionFor (lib.versions.major pkgs.ungoogled-chromium.version);
      in
      [
        (createChromiumExtension {
          # adblocker for youtube
          id = "cmedhionkhpnakcndndgjdbohmhepckk";
          sha256 = "sha256:1qbz56w7rwhcbsb9mg3n3fsgcqz4vxkww38jpcnf67z16zbpk1y5";
          version = "7.0.4";
        })
      ];
      commandLineArgs = [
        "--remote-debugging-port=9222"
        "--remote-allow-origins=*"
        "--force-dark-mode"
        "--restore-last-session"
      ];
    };

    # Enable the X11 windowing system.
    services = {
      libinput.enable = true;

      displayManager = {
        defaultSession = "none+openbox";
        autoLogin = {
          user = "display";
          enable = true;
        };
      };

      xserver = {
        enable = true;
        xkb.layout = "us"; # keyboard layout

        # Let lightdm handle autologin
        displayManager.lightdm = {
          enable = true;
        };

        # Start openbox after autologin
        windowManager.openbox.enable = true;
      };
    };

    # Overlay to set custom autostart script for openbox
    nixpkgs.overlays = with pkgs; [
      (_self: super: {
        openbox = super.openbox.overrideAttrs (_oldAttrs: rec {
          postFixup = ''
            ln -sf /etc/openbox/autostart $out/etc/xdg/openbox/autostart
          '';
        });
      })
    ];

    # By defining the script source outside of the overlay, we don't have to
    # rebuild the package every time we change the startup script.
    environment.etc."openbox/autostart".source = pkgs.writeScript "autostart" ''
      #!${pkgs.bash}/bin/bash
      # End all lines with '&' to not halt startup script execution

      # Keep screen on
      xset -dpms     & # Disable DPMS (Energy Star) features
      xset s off     & # Disable screensaver
      xset s noblank & # Don't blank video device

      # Start chromium
      chromium &
    '';

    # Prevent hibernating
    systemd.targets.sleep.enable = false;
    systemd.targets.suspend.enable = false;
    systemd.targets.hibernate.enable = false;
    systemd.targets.hybrid-sleep.enable = false;
    powerManagement.enable = false;

  };
}
