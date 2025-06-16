{ config, lib, pkgs, ... }:
{

  services.tang = {
    enable = true;

    ipAddressAllow = [ "192.168.1.0/24" ];
    listenStream = [ "0.0.0.0:7654" ];
  };

  # Ensure that the tang server doesn't work if the bind mount
  # for /var/lib/private isn't there
  systemd.sockets.tangd = {
    after = [
      "var-lib-private-tang.mount"
    ];
    requires = [
      "var-lib-private-tang.mount"
    ];
  };

  # Bind mount from the `sec` filesystem
  fileSystems."/var/lib/private/tang" = {
    device = "/sec/tang";
    options = [ "bind" "nofail" ];
    depends = [ "/sec" ];
  };  
}