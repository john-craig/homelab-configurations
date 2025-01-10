{ pkgs, lib, config, ... }: let 
  autheliaConfig = {
    server = {
      host = "0.0.0.0";
      port = 9091;
    };

    log.level = "info";

    totp = {
      issuer = "chiliahedron.wtf";
      period = 30;
      skew = 1;
    };

    authentication_backend = {
      disable_reset_password = true;
      refresh_interval: "5m";

      file = {
        path = "/var/lib/authelia/users_database.yml";
        password = {
          algorithm = "argon2id";
          iterations = 4;
          key_length = 32;
          salt_length = 16;
          memory = 4096;
          parallelism = 8;
        };
      };
    };

    access_control = {
      default_policy = "deny";
      rules = [
        {
          domain = [ "authelia.chiliahedron.wtf" ];
          policy = "bypass";
        }
        {
          domain = [ "chiliahedron.wtf" "*.chiliahedron.wtf" ];
          policy = "one_factor";
        }
      ];
    };

    session = {
      name = "authelia_session";
      expiration = 86400; # 1 day
      inactivity = 3600;  # 1 hour
      domain = "chiliahedron.wtf";
    };

    regulation = {
      max_retries = 3;
      find_time = "10m";
      ban_time = "12h";
    };

    storage = {
      local.path = "/var/lib/authelia/db.sqlite";
    }
  };

  autheliaSecrets = {
    jwtSecretFile = ;
    sessionSecretFile = ;
    storageEncryptionKeyFile = ;
  };
in {
  options = {
    containerProxies = {
      enable = lib.mkEnableOption "configuration for Podman container proxies";
    };
  };

  config = lib.mkIf config.containerProxies.enable {
    services.traefik = {
      enable = true;

      environmentFiles = [
        "/run/secrets/traefik/root/cloudflare_dns_token"
      ];

      staticConfigOptions = {
        core.defaultRuleSyntax = "v2";
        
        api = { 
          insecure = true;
          dashboard = true;
        };

        entryPoints = {
          web = {
            address = ":80";
            forwardedHeaders = {
              insecure = false;
            };

            http = {
              redirections = {
                entryPoint = {
                  to = "websecure";
                  scheme = "https";
                };
              };
            };
          };

          websecure = {
            address = ":443";
            forwardedHeaders = {
              insecure = false;
            };
          };
        };

        providers = {
          docker = {
            endpoint = "unix:///var/run/podman/podman.sock";
            exposedByDefault = false;

            network = "chiliahedron-services";
          };
        };

        certificatesResolvers = {
          "chiliahedron-resolver" = {
            acme = {
              storage = "/var/run/traefik/acme.json";
              dnsChallenge = {
                provider = "cloudflare";
                delayBeforeCheck = 0;
                resolvers = [
                  "1.1.1.1:53"
                  "8.8.8.8:53"
                ];
              };
            };
          };
        };
      };
    };   
  };
}
