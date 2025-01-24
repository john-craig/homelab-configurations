{ pkgs, lib, config, ... }: {
  config = {
    services.nfs.server.enable = true;
    services.nfs.server.exports = ''
      /export         192.168.1.0/24(rw,fsid=0,no_subtree_check)
      /export/media   192.168.1.0/24(rw,nohide,insecure,no_subtree_check)
    '';
  };
}
