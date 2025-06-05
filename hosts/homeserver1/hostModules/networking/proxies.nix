{ pkgs, lib, config, ... }: {
  options = {
    serviceProxies = {
      enable = lib.mkEnableOption "configuration for Service proxies";

      resolverName = lib.mkOption {
        type = lib.types.str;
      };

      internalRules = lib.mkOption {
        type = lib.types.str;
      };

      containers = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "configuration for Container proxies";

            networkName = lib.mkOption {
              type = lib.types.str;
            };
          };
        };
        default = { };
      };

      extraProxies = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            hostname = lib.mkOption {
              type = lib.types.str;
            };

            redirect = lib.mkOption {
              type = lib.types.str;
            };
          };
        });
        default = [ ];
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (config.serviceProxies.enable &&
       config.serviceProxies.containers.enable) {
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
        "A ${podmanDir}/podman.sock - - - - user::rwx"
        "A ${podmanDir}/podman.sock - - - - group::r-x"
        "A ${podmanDir}/podman.sock - - - - mask::rwx"
        "A+ ${podmanDir}/podman.sock - - - - user:traefik:rwx"
        "A+ ${podmanDir}/podman.sock - - - - group:traefik:rwx"
      ];

    services.traefik = {
      enable = true;

      environmentFiles = [
        config.sops.secrets."traefik/traefik/cloudflare_dns_token".path
      ];

      staticConfigOptions = {
        providers = {
          docker = {
            endpoint = "unix:///var/run/podman/podman.sock";
            exposedByDefault = false;

            network = "${config.serviceProxies.containers.networkName}";
          };
        };
      };
    };
  }) (lib.mkIf (config.serviceProxies.enable) {
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

        certificatesResolvers = {
          "${config.serviceProxies.resolverName}" = {
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
          routers = lib.lists.foldr
            (proxyDef: acc: 
              acc // {
                "${proxyDef.hostname}" = {
                  entryPoints = [ "websecure" ];
                  rule = "Host(`${proxyDef.hostname}`) && ${config.serviceProxies.internalRules}";
                  service = "${proxyDef.hostname}";
                  tls = {
                    certResolver = "${config.serviceProxies.resolverName}";
                  };
                };
              }
            ) { } config.serviceProxies.extraProxies;

          services = lib.lists.foldr
            (proxyDef: acc: 
              acc // {
                "${proxyDef.hostname}" = {
                  loadBalancer.servers = [
                    { url = "${proxyDef.redirect}"; }
                  ];
                };
              }
            ) { } config.serviceProxies.extraProxies;
        };
      };
    };
  })];
}
