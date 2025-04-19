{ config, pkgs, ... }:

let
  wgInterface = "wg0";
  wgIp = "10.100.0.2/24";
  bastion0Pubkey = "znu1Ld2uFAVnyjC/wEzkvBgA1Q6KW/GzLd2+Q8egLBE="; # Replace with Server A's public key
  endpoint = "45.33.8.38:51820"; # Server A's public IP and port
in {
  networking.wireguard.interfaces.${wgInterface} = {
    ips = [ wgIp ];
    privateKeyFile = config.sops.secrets."wireguard/root/private-key.b64".path;

    peers = [
      {
        publicKey = bastion0Pubkey;
        allowedIPs = [ "10.100.0.0/24" ];
        endpoint = endpoint;
        persistentKeepalive = 25; # Keeps NAT open
      }
    ];
  };
}
