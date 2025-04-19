{ pkgs, lib, config, ... }: {
  options = {
    selfhosting = {
      enable = lib.mkEnableOption "self-hosted services";
    };
  };

  config = lib.mkIf config.selfhosting.enable {
    services.gallipedal = {
      enable = true;
      services = {
        "audiobookshelf" = {
          enable = true;
          containers."audiobookshelf" = {
            ports = {
              "80".hostPort = "7591";
            };
            volumes = {
              "/config".hostPath = "/srv/container/audiobookshelf/config";
              "/metadata".hostPath = "/srv/container/audiobookshelf/metadata";
              "/audiobooks".hostPath = "/srv/media/by_category/audio/audiobooks";
              "/podcasts".hostPath = "/srv/media/by_category/audio/podcasts";
            };
          };
        };

        "archivebox" = {
          enable = true;
          containers = {
            "archivebox" = {
              environment = {
                ADMIN_USERNAME = "admin";
                ALLOWED_HOSTS = "*";
                PUBLIC_ADD_VIEW = "True";
                PUBLIC_INDEX = "True";
                PUBLIC_SNAPSHOTS = "True";
                SAVE_ARCHIVE_DOT_ORG = "False";
                SEARCH_BACKEND_ENGINE = "sonic";
                SEARCH_BACKEND_HOST_NAME = "sonic";
                PUID = "1000";
                PGID = "1000";
              };

              secrets = {
                ADMIN_PASSWORD = "/run/secrets/gallipedal/secrets/archivebox/ADMIN_PASSWORD";
                SEARCH_BACKEND_PASSWORD = "/run/secrets/gallipedal/secrets/archivebox/SEARCH_BACKEND_PASSWORD";
              };

              volumes = {
                "/data".hostPath = "/srv/container/archivebox/data";
              };

              ports = {
                "8000".hostPort = "8112";
              };
            };

            "sonic" = {
              secrets = {
                SEARCH_BACKEND_PASSWORD = "/run/secrets/gallipedal/secrets/archivebox/SEARCH_BACKEND_PASSWORD";
              };

              volumes = {
                "/var/lib/sonic/store".hostPath = "/srv/container/sonic/data";
                "/etc/sonic.cfg".hostPath = "/srv/container/sonic/sonic.cfg";
              };
            };
          };
        };

        "authelia" = {
          enable = true;
          containers."authelia" = {
            environment = {
              TZ = "America/New_York";
            };

            ports = {
              "9091".hostPort = "9091";
            };

            volumes = {
              "/config".hostPath = "/srv/container/authelia/config";
            };

            extraOptions = [
              "--network-alias=authelia"
              "--network=chiliahedron-services"
            ];
          };
        };

        "code-server" = {
          enable = true;
          containers."code-server" = {
            environment = {
              DEFAULT_WORKSPACE = "/programming";
              PGID = "1000";
              PUID = "1000";
              TZ = "America/New_York";
            };

            volumes = {
              "/config".hostPath = "/srv/container/code-server/config";
              "/programming".hostPath = "/srv/programming";
            };

            ports = {
              "8443".hostPort = "8443";
            };
          };
        };

        "dev-blog" = {
          enable = true;
          containers."dev-blog" = {
            volumes = {
              "/app/ext/pages/blog".hostPath = "/srv/container/gatsby-dev-blog/blog";
            };

            ports = {
              "9000".hostPort = "6787";
            };
          };
        };

        "gitea" = {
          enable = true;
          containers."gitea" = {
            containerUser = "1000:1000";
            environment = {
              USER_GID = "1000";
              USER_UID = "1000";
              GITEA_APP_INI = "/data/gitea/conf/app.ini";
              GITEA_TMP = "/data/gitea/tmp";
              GITEA_CUSTOM = "/data/gitea";
              GITEA_WORK_DIR = "/app/gitea/gitea";
            };

            volumes = {
              "/etc/localtime".hostPath = "/etc/localtime";
              "/etc/timezone".hostPath = "/etc/timezone";
              "/data".hostPath = "/srv/container/gitea/data";
            };

            ports = {
              "3000".hostPort = "6080";
              "2222".hostPort = "6022";
            };
          };
        };

        "gotify" = {
          enable = true;
          containers."gotify" = {
            secrets = {
              GOTIFY_DEFAULTUSER_PASS = "/run/secrets/gallipedal/secrets/gotify/GOTIFY_DEFAULTUSER_PASS";
            };

            volumes = {
              "/app/data".hostPath = "/srv/container/gotify/data";
            };

            ports = {
              "80".hostPort = "9703";
            };
          };
        };

        "grocy" = {
          enable = true;
          containers."grocy" = {
            environment = {
              PGID = "1000";
              PUID = "1000";
              TZ = "America/New_York";
            };

            volumes = {
              "/config".hostPath = "/srv/container/grocy/data";
            };

            ports = {
              "80".hostPort = "9283";
            };
          };
        };

        "hakatime" = {
          enable = true;
          containers = {
            "hakatime" = {
              environment = {
                "HAKA_DB_HOST" = "haka_db";
                "HAKA_DB_PORT" = "5432";
                "HAKA_DB_NAME" = "haka";
                "HAKA_DB_USER" = "haka";

                "HAKA_BADGE_URL" = "https://hakatime.chiliahedron.wtf";
                "HAKA_PORT" = "8080";
                "HAKA_SHIELD_IO_URL" = "https://img.shields.io";
                "HAKA_ENABLE_REGISTRATION" = "true";

                "HAKA_SESSION_EXPIRY" = "24";
                "HAKA_LOG_LEVEL" = "info";
                "HAKA_ENV" = "dev";
              };

              secrets = {
                "HAKA_DB_PASS" = "/run/secrets/gallipedal/secrets/hakatime/HAKA_DB_PASS";
              };

              ports = {
                "8080".hostPort = "6653";
              };
            };

            "haka_db" = {
              environment = {
                "POSTGRES_DB" = "haka";
                "POSTGRES_USER" = "haka";
              };

              secrets = {
                "POSTGRES_PASSWORD" = "/run/secrets/gallipedal/secrets/hakatime/HAKA_DB_PASS";
              };

              volumes = {
                "/var/lib/postgresql/data".hostPath = "/srv/container/hakatime/data";
              };
            };
          };
        };

        "home-assistant" = {
          enable = true;
          containers."hass" = {
            volumes = {
              "/etc/localtime".hostPath = "/etc/localtime";
              "/config".hostPath = "/srv/container/home-assistant/config";
            };

            ports = {
              "8123".hostPort = "8123";
            };
          };
        };

        "homepage" = {
          enable = true;
          containers."homepage" = {
            volumes = {
              "/app/config".hostPath = "/srv/container/hompage/config";
            };

            ports = {
              "3000".hostPort = "1081";
            };
          };
        };

        "invidious" = {
          enable = false;
          containers = {
            "invidious" = {
              volumes = {
                "/invidious/config/config.yml".hostPath = "/srv/container/invidious/config.yaml";
              };

              ports = {
                "3001".hostPort = "3001";
              };
            };

            "invidious-db" = {
              environment = {
                POSTGRES_DB = "invidious";
                POSTGRES_USER = "kemal";
              };

              secrets = {
                POSTGRES_PASSWORD = "/run/secrets/gallipedal/secrets/invidious/POSTGRES_PASSWORD";
              };

              volumes = {
                "/config/sql".hostPath = "/srv/container/invidious/config/sql";
                "/var/lib/postgresql/data".hostPath = "/srv/container/invidious/data";
                "/docker-entrypoint-initdb.d/init-invidious-db.sh".hostPath = "/srv/container/invidious/init-invidious-db.sh";
              };
            };
          };
        };

        "jellyfin" = {
          enable = true;
          containers."jellyfin" = {
            environment = {
              PGID = "1000";
              PUID = "1000";
              TZ = "America/New_York";
            };

            volumes = {
              "/cache".hostPath = "/srv/container/jellyfin/cache";
              "/config".hostPath = "/srv/container/jellyfin/config";
              "/media".hostPath = "/srv/media";
            };

            ports = {
              "8096".hostPort = "8096";
              "8920".hostPort = "8920";
              "7359".hostPort = "7359";
              "1900".hostPort = "1900";
            };
          };
        };

        "monitoring" = {
          enable = true;
          containers = {
            "grafana" = {
              volumes = {
                "/var/lib/grafana".hostPath = "/srv/container/grafana/data";
              };

              ports = {
                "3000".hostPort = "3000";
              };
            };

            "prometheus" = {
              volumes = {
                "/etc/prometheus".hostPath = "/srv/container/prometheus/config";
                "/prometheus".hostPath = "/srv/container/prometheus/data";
              };

              ports = {
                "9090".hostPort = "9090";
              };
            };

            "influxdb" = {
              volumes = {
                "/etc/influxdb2".hostPath = "/srv/container/influxdb/config";
                "/var/lib/influxdb2".hostPath = "/srv/container/influxdb/db";
              };

              ports = {
                "8086".hostPort = "8086";
              };
            };
          };
        };

        "nocodb" = {
          enable = true;
          containers = {
            "nocodb" = {
              secrets = {
                NC_DB = "/run/secrets/gallipedal/secrets/nocodb/NC_DB";
              };

              volumes = {
                "/usr/app/data".hostPath = "/srv/container/nocodb/app";
              };

              ports = {
                "8080".hostPort = "9979";
              };
            };

            "root_db" = {
              environment = {
                POSTGRES_DB = "root_db";
                POSTGRES_USER = "postgres";
              };

              secrets = {
                POSTGRES_PASSWORD = "/run/secrets/gallipedal/secrets/nocodb/POSTGRES_PASSWORD";
              };

              volumes = {
                "/var/lib/postgresql/data".hostPath = "/srv/container/nocodb/data";
              };

              ports = {
                "5432".hostPort = "9799";
              };
            };
          };
        };

        "n8n" = {
          enable = true;
          containers."n8n" = {
            environment = {
              "N8N_HOST" = "n8n.chiliahedron.wtf";
              "N8N_PORT" = "5678";
              "N8N_PROTOCOL" = "https";
              "NODE_ENV" = "production";
              "WEBHOOK_URL" = "https://n8n.chiliahedron.wtf/";
              "GENERIC_TIMEZONE" = "America/New_York";
            };

            ports = {
              "5678".hostPort = "9715";
            };

            volumes = {
              "/home/node/.n8n".hostPath = "/srv/container/n8n/data";
            };
          };
        };

        "obsidian-remote" = {
          enable = true;
          containers."obsidian-remote" = {
            environment = {
              DOCKER_MODS = "linuxserver/mods:universal-git";
              PGID = "1000";
              PUID = "1000";
              TZ = "America/New_York";
            };

            volumes = {
              "/config".hostPath = "/srv/container/obsidian-remote/config";
              "/vaults/main".hostPath = "/srv/documents/by_category/vault";
            };

            ports = {
              "8080".hostPort = "5691";
            };
          };
        };

        "owntracks" = {
          enable = true;
          containers = {
            "otrecorder" = {
              environment = {
                OTR_HTTPPORT = "8084";
                OTR_HTTPHOST = "0.0.0.0";
                OTR_PORT = "0";
              };

              volumes = {
                "/config".hostPath = "/srv/container/owntracks/config";
                "/store".hostPath = "/srv/container/owntracks/data";
              };

              ports = {
                "8083".hostPort = "8083";
                "8084".hostPort = "8084";
              };
            };
          };
        };

        "paperless-ngx" = {
          enable = true;
          containers = {
            "broker" = {
              volumes = {
                "/data".hostPath = "/srv/container/paperless-ngx/redisdata";
              };
            };

            "webserver" = {
              environment = {
                PAPERLESS_REDIS = "redis://broker:6379";
                USERMAP_UID = "1000";
                USERMAP_GID = "1000";
                PAPERLESS_URL = "https://paperless.chiliahedron.wtf";
                PAPERLESS_SECRET_KEY = "change-me";
                PAPERLESS_TIME_ZONE = "America/New_York";
                PAPERLESS_OCR_LANGUAGE = "eng";
              };

              volumes = {
                "/usr/src/paperless/data".hostPath = "/srv/container/paperless-ngx/data";
                "/usr/src/paperless/media".hostPath = "/srv/container/paperless-ngx/media";
                "/usr/src/paperless/export".hostPath = "/srv/container/paperless-ngx/export";
                "/usr/src/paperless/consume".hostPath = "/srv/container/paperless-ngx/consume";
              };

              ports = {
                "8000".hostPort = "8000";
              };
            };
          };
        };

        "protonmail-bridge" = {
          enable = true;
          containers = {
            "offlineimap" = {
              # UID/GID = 911:911
              environment = {
                CRON_SCHEDULE = "* * * * *";
                # CRON_SCHEDULE = "0 * * * *";
              };

              volumes = {
                "/vol/config".hostPath = "/srv/container/offlineimap/config";
                "/vol/mail".hostPath = "/srv/container/offlineimap/mail";
                "/vol/secrets".hostPath = "/srv/container/offlineimap/secrets";
              };
            };

            "bridge" = {
              volumes = {
                "/root".hostPath = "/srv/container/protonmail-bridge";
              };

              ports = {
                "25".hostPort = "1025";
                "143".hostPort = "1143";
              };
            };
          };
        };

        "registry" = {
          enable = true;
          containers."registry" = {
            volumes = {
              "/var/lib/registry".hostPath = "/srv/container/registry/data";
            };

            ports = {
              "5000".hostPort = "5000";
            };
          };
        };

        # "rhasspy-base" = {
        #   enable = true;
        #   containers."base" = {
        #     volumes = {
        #       "/etc/localtime".hostPath = "/etc/localtime";
        #       "/profiles".hostPath = "/srv/container/rhasspy-base/profiles";
        #     };

        #     ports = {
        #       "12101".hostPort = "12101";
        #       "12183".hostPort = "12183";
        #     };
        #   };
        # };

        # "rhasspy-satellite" = {
        #   enable = true;
        #   containers."satellite" = {
        #     volumes = {
        #       "/etc/localtime".hostPath = "/etc/localtime";
        #       "/profiles".hostPath = "/srv/container/rhasspy-satellite/profiles";
        #     };

        #     ports = {
        #       "12101".hostPort = "12101";
        #       "12183".hostPort = "12183";
        #       "12333".hostPort = "12333";
        #     };
        #   };
        # };

        # "timeflip-tracker" = {
        #   enable = true;
        #   containers = {
        #     "tracker" = {
        #       environment = {
        #         LOG_LEVEL = "DEBUG";
        #         MARIADB_DATABASE = "timeflip";
        #         MARIADB_HOST = "timeflip-tracker-database";
        #         MARIADB_PASSWORD = "timeflip";
        #         MARIADB_PORT = "3306";
        #         MARIADB_USER = "timeflip";
        #       };

        #       volumes = {
        #         "/etc/timeflip-tracker/config.yaml".hostPath = "/srv/container/timeflip-tracker/config/config.yaml";
        #         "/var/run/dbus".hostPath = "/run/dbus";
        #       };
        #     };

        #     "database" = {
        #       environment = {
        #         MARIADB_DATABASE = "timeflip";
        #         MARIADB_PASSWORD = "timeflip";
        #         MARIADB_RANDOM_ROOT_PASSWORD = "1";
        #         MARIADB_USER = "timeflip";
        #       };

        #       volumes = {
        #         "/var/lib/mysql".hostPath = "/srv/container/timeflip-tracker/data";
        #       };

        #       ports = {
        #         "3306".hostPort = "3307";
        #       };
        #     };
        #   };
        # };

        "status-page" = {
          enable = true;
          containers."httpd" = {
            volumes = {
              "/usr/local/apache2/htdocs".hostPath = "/srv/container/status-page";
            };
          };
        };

        "syncthing" = {
          enable = true;
          containers."syncthing" = {
            environment = {
              PGID = "1000";
              PUID = "1000";
              TZ = "America/New_York";
              UMASK_SET = "022";
            };

            volumes = {
              "/sync/documents".hostPath = "/srv/documents";
              "/sync/media".hostPath = "/srv/media";
              "/sync/programming".hostPath = "/srv/programming";
              "/config".hostPath = "/srv/container/syncthing";
            };

            ports = {
              "8384".hostPort = "8384";
              "22000".hostPort = "22000";
              "21027".hostPort = "21027";
            };
          };
        };

        "torrenting" = {
          enable = true;
          containers = {
            "prowlarr" = {
              environment = {
                PGID = "1000";
                PUID = "1000";
                TZ = "America/New_York";
              };

              volumes = {
                "/config".hostPath = "/srv/container/prowlarr/config";
              };

              ports = {
                "9696".hostPort = "9696";
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

              ports = {
                "7878".hostPort = "7878";
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

              ports = {
                "8989".hostPort = "8989";
              };
            };

            "resilio" = {
              environment = {
                RSLSYNC_TRASH_TIME = "1";
                RSLSYNC_SIZE = "100000";
                PGID = "1000";
                PUID = "1000";
                TZ = "America/New_York";
                STORAGE_DIR = "/srv";
              };

              secrets = {
                RSLSYNC_SECRET = "/run/secrets/gallipedal/secrets/torrenting/RSLSYNC_SECRET";
              };

              volumes = {
                "/data".hostPath = "/srv/downloads";
              };

              ports = {
                "8888".hostPort = "8888";
                "33333".hostPort = "33333";
              };
            };
          };
        };

        "vaultwarden" = {
          enable = true;
          containers."vaultwarden" = {
            environment = {
              DOMAIN = "https://vaultwarden.chiliahedron.wtf";
            };

            volumes = {
              "/data".hostPath = "/srv/container/vaultwarden/data";
            };

            ports = {
              "80".hostPort = "6513";
            };
          };
        };
      };

      proxyConf = {
        internalRules = "HeadersRegexp(`X-Real-Ip`, `(^192\.168\.[0-9]+\.[0-9]+)|(^10\.100\.0\.16)`)";
        network = "chiliahedron-services";
        tlsResolver = "chiliahedron-resolver";
      };
    };

  };
}
