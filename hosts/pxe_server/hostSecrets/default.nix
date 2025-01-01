{ pkgs, lib, config, ... }: {

  # This is the actual specification of the secrets.
  sops.secrets."s3cmd/backup/s3cfg" = {
    mode = "0440";
    # owner = config.users.users.backup.name;
    # group = config.users.users.backup.group;

    sopsFile = ./s3cmd.yaml;
  };

  sops.secrets."openssh/backup/id_backup" = {
    mode = "0400";
    # owner = config.users.users.backup.name;
    # group = config.users.users.backup.group;

    sopsFile = ./openssh.yaml;
  };
}
