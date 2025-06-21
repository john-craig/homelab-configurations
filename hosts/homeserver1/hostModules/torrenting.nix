{ config, pkgs, lib, ... }:

let
  sshUser = "psb62860";
  sshHost = "psb62860.seedbox.io";
  remotePath = "files/CompletedDownloads";
  mountPoint = "/srv/downloads";
  passwordFile = "/run/secrets/torrenting/sshfs/SSHFS_PASSWORD";  # Should be 0600 root-owned
in
{

  services.gallipedal = {
    enable = true;

    services."torrenting" = {
      enable = true;
      containers = {
        "wireguard" = {
          volumes = {
            "/etc/wireguard".hostPath = "/srv/container/wireguard/config";
          };

          environment = {
            "ALLOWED_SUBNETS" = "";
          };

          ports = {
            "9696".hostPort = "9696";
            "7878".hostPort = "7878";
            "8989".hostPort = "8989";
            "8686".hostPort = "8686";
          };
        };

        # "protonwire" = {
        #   # [Interface]
        #   # # Bouncing = 1
        #   # # NAT-PMP (Port Forwarding) = off
        #   # # VPN Accelerator = on
        #   # PrivateKey = SIcCxOKmBAsfYJtrqr+ITg96rRos9PdO/sp4nJ6wtFw=
        #   # Address = 10.2.0.2/32
        #   # DNS = 10.2.0.1

        #   # [Peer]
        #   # # NL-FREE#103
        #   # PublicKey = avWNWfLsQAQhnRAioRnpZ2LI1nMqd73lWr5zt4aZ1Vo=
        #   # AllowedIPs = 0.0.0.0/0
        #   # Endpoint = 212.8.253.155:51820

        #   environment = {
        #     "PROTONVPN_SERVER" = "212.8.253.155";
        #     "KILL_SWITCH" = "0";
        #     "DEBUG" = "1";
        #   };

        #   secrets = {
        #     WIREGUARD_PRIVATE_KEY = "/run/secrets/gallipedal/secrets/torrenting/WIREGUARD_PRIVATE_KEY";
        #   };

        #   ports = {
        #     "9696".hostPort = "9696";
        #     "7878".hostPort = "7878";
        #     "8989".hostPort = "8989";
        #     "8686".hostPort = "8686";
        #   };
        # };

        "prowlarr" = {
          environment = {
            PGID = "1000";
            PUID = "1000";
            TZ = "America/New_York";
          };

          volumes = {
            "/config".hostPath = "/srv/container/prowlarr/config";
          };
        };

        "radarr" = {
          environment = {
            PGID = "1000";
            PUID = "1000";
            TZ = "America/New_York";
          };

          volumes = {
            "/config".hostPath = "/srv/container/radarr/config";
            "/movies".hostPath = "/srv/media/by_category/video/movies";
            "/downloads/radarr".hostPath = "/srv/downloads/radarr";
          };
        };

        "sonarr" = {
          environment = {
            PGID = "1000";
            PUID = "1000";
            TZ = "America/New_York";
          };

          volumes = {
            "/config".hostPath = "/srv/container/sonarr/config";
            "/tv".hostPath = "/srv/media/by_category/video/shows";
            "/downloads/sonarr".hostPath = "/srv/downloads/tv-sonarr";
          };
        };

        "lidarr" = {
          environment = {
            PGID = "1000";
            PUID = "1000";
            TZ = "America/New_York";
          };

          volumes = {
            "/config".hostPath = "/srv/container/lidarr/config";
            "/music".hostPath = "/srv/media/by_category/audio/music";
            "/downloads/lidarr".hostPath = "/srv/downloads/lidarr";
          };
        };

        "lidatube" = {
          environment = {
            "lidarr_address" = "http://0.0.0.0:8686";
            "attempt_lidarr_import" = "True";
          };

          secrets = {
            "lidarr_api_key" = "/run/secrets/gallipedal/secrets/torrenting/LIDARR_API_KEY";
          };

          volumes = {
            "/lidatube/config".hostPath = "/srv/container/lidatube/config";
            "/lidatube/downloads".hostPath = "/srv/media/by_category/audio/music";
            # "/etc/localtime".hostPath = "/etc/localtime";
          };

          ports = {
            "5000".hostPort = "8687";
          };
        };

        "yt-dlp-webui" = {
          volumes = {
            "/downloads".hostPath = "/srv/media/by_category/uncategorized";
          };

          ports = {
            "3033".hostPort = "8688";
          };
        };
      };
    };
  };

  # Install required packages
  environment.systemPackages = with pkgs; [
    sshfs
    sshpass
  ];

  systemd.tmpfiles.rules = [
    "Z /srv/downloads/lidarr 777"
    "Z /srv/downloads/tv-sonarr 777"
    "Z /srv/downloads/radarr 777"
    "Z /srv/downloads/readarr 777"
    "Z /srv/media/by_category/audio/music 777"
    "Z /srv/media/by_category/video/shows 777"
    "Z /srv/media/by_category/video/movies 777"
  ];

  virtualisation.oci-containers.containers = {
    "torrenting-prowlarr".extraOptions = lib.mkForce [
      "--network=container:torrenting-wireguard"
    ];
    "torrenting-radarr".extraOptions = lib.mkForce [
      "--network=container:torrenting-wireguard"
    ];
    "torrenting-sonarr".extraOptions = lib.mkForce [
      "--network=container:torrenting-wireguard"
    ];
    "torrenting-lidarr".extraOptions = lib.mkForce [
      "--network=container:torrenting-wireguard"
    ];
  };

  systemd.services = {
    "podman-mount-torrenting-radarr".serviceConfig = {
      after = [ "seedboxio-sshfs-mount.service" ];
      requires = [ "seedboxio-sshfs-mount.service" ];
    };
    
    "podman-mount-torrenting-sonarr".serviceConfig = {
      after = [ "seedboxio-sshfs-mount.service" ];
      requires = [ "seedboxio-sshfs-mount.service" ];
    };

    "podman-mount-torrenting-lidarr".serviceConfig = {
      after = [ "seedboxio-sshfs-mount.service" ];
      requires = [ "seedboxio-sshfs-mount.service" ];
    };
    
    "seedboxio-sshfs-mount" = {
      description = "Mount remote SSHFS share at ${mountPoint}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
          # Get the PID of the wireguard container
        wireguard_pid=$(${pkgs.podman}/bin/podman inspect --format '{{.State.Pid}}' torrenting-wireguard)

        # Use nsenter to enter its network namespace and run sshfs
        ${pkgs.util-linux}/bin/nsenter --net=/proc/$wireguard_pid/ns/net \
        ${pkgs.coreutils}/bin/cat ${passwordFile} | \
        ${pkgs.sshfs}/bin/sshfs \
          -o password_stdin \
          -o reconnect \
          -o allow_other \
          -o IdentityFile=/dev/null \
          -o StrictHostKeyChecking=no \
          -o HostKeyAlgorithms=+ssh-rsa \
          ${sshUser}@${sshHost}:${remotePath} ${mountPoint}
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountPoint}";
      };
    };
  };
}
