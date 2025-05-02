{ pkgs, lib, config, ... }: {
  # This will automatically import SSH keys as age keys
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # This is using an age key that is expected to already be in the filesystem
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # This will generate a new key if the key specified above does not exist
  sops.age.generateKey = true;

  # This is the actual specification of the secrets.
  sops.secrets."gotify/notifier/api_key" = {
    sopsFile = ./gotify.yaml;
  };

  sops.secrets."nocodb/service/api_token" = {
    mode = "0400";
    owner = "service";

    sopsFile = ./nocodb.yaml;
  };

  sops.secrets."openssh/root/cacher" = {
    mode = "0400";
    owner = "root";

    sopsFile = ./openssh.yaml;
  };
}
