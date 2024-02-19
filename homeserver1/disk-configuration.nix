{ lib, ... }:
{
  imports = [ "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix" ];

  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault "/dev/sdc";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          mnt = {
            name = "mount";
            size = "100%";
            content = {
              type = "filesystem";
              format = "btrfs";
              mountpoint = "/mnt";
              mountOptions = [
                "defaults"
              ];
            };
          };
        };
      };
    };
  };
}
