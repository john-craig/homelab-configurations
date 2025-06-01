{ pkgs, lib, config, ... }: {
  options = {
    containerProxies = {
      enable = lib.mkEnableOption "configuration for Podman container proxies";
    };
  };

  config = lib.mkIf config.containerProxies.enable {
    systemd.tmpfiles.rules =
      let
        podmanDir = "/var/run/podman";
      in
      [
        "A ${podmanDir} - - - - user::rwx"
        "A ${podmanDir} - - - - group::r-x"
        "A ${podmanDir} - - - - mask::rwx"
        "A+ ${podmanDir} - - - - user:traefik:rwx"
        "A+ ${podmanDir} - - - - group:traefik:rwx"
      ];

    services.traefik = {
      enable = true;

      environmentFiles = [
        config.sops.secrets."traefik/traefik/cloudflare_dns_token".path
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

      dynamicConfigOptions = {
        http = {
          routers."home-assistant" = {
            entryPoints = [ "websecure" ];
            rule = "Host(`home-assistant.chiliahedron.wtf`) && HeadersRegexp(`X-Real-Ip`, `(^192\.168\.[0-9]+\.[0-9]+)|(^10\.100\.0\.[0-9]+)`)";
            service = "home-assistant";
            tls = {
              certResolver = "chiliahedron-resolver";
            };
          };

          services."home-assistant" = {
            loadBalancer.servers = [
              { url = "http://192.168.1.8:8123"; }
            ];
          };
        };
      };
    };
  };
}
