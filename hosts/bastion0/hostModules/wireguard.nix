{ config, pkgs, ... }:

let
  wgPort = 51820;
  wgInterface = "wg0";
  wgIp = "10.100.0.1/24";

  homeserver1Pubkey = "FOGqroNciRPSDqptv/VVNz+ESr4UvmB8djEhK87mgGc=";
  pixel4aPubkey = "sK4dhOJbASYTpOkxB3I3Vzx1bmUPKvvremXr+t6f6CU=";
  laptopPubkey = "iLXcO6WzweMsIRzI54/diOHJXGlsDXpubXjIDif4Z2U=";

  profileLag = {
    pubkey = "5q3Ke4VR/+q2ETqb1r428W51/LV+pnpMHgljzNSmkW0=";
    ipAddress = "10.100.0.56";
  };
in
{
  networking.firewall.allowedUDPPorts = [ wgPort ];

  networking.wireguard.interfaces.${wgInterface} = {
    ips = [ wgIp ];
    listenPort = wgPort;
    privateKeyFile = config.sops.secrets."wireguard/root/private-key.b64".path;

    peers = [
      {
        publicKey = homeserver1Pubkey;
        allowedIPs = [ "10.100.0.2/32" ];
      }
      {
        publicKey = pixel4aPubkey;
        allowedIPs = [ "10.100.0.16/32" ];
      }
      {
        publicKey = laptopPubkey;
        allowedIPs = [ "10.100.0.33/32" ];
      }
      {
        publicKey = profileLag.pubkey;
        allowedIPs = [ "${profileLag.ipAddress}/32" ];
      }
    ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
  };
}
