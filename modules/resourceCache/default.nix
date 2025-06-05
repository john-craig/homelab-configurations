{ pkgs, lib, config, ... }: {
  options = {
    resourceCache = {
      enable = lib.mkEnableOption "Cache Server services";

      role = lib.mkOption {
        type = lib.types.enum [ "client" "server" "both" ];
        default = "client"; # default value
        description = "Defines whether the configuration is for the client, server, or both.";
      };

      credentials = lib.mkOption {
        default = { };
        type = lib.types.submodule {
          options = {
            publicKey = lib.mkOption {
              type = lib.types.str;
            };

            privateKey = lib.mkOption {
              type = lib.types.str;
            };
          };
        };
      };

      resources = lib.mkOption {
        default = { };
        type = lib.types.submodule {
          options = {
            pacman = lib.mkOption {
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkEnableOption "Archlinux package caching";
                };
              };
            };

            nix = lib.mkOption {
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkEnableOption "Nix package caching";
                };
              };
            };
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    ##################################################
    # Server Configuration: Common
    ##################################################
    (let
      # dustman
      dustman = (pkgs.writeShellScriptBin "dustman" ''
        #!/usr/bin/env bash

        set -euo pipefail

        GENERATIONS=2
        BASE_DIR="/var/lib/dustman"
        TIMESTAMP=$(date +%s)

        DRY_RUN=false
        if [[ "''${1:-}" == "--dry-run" ]]; then
          DRY_RUN=true
          echo "[dustman] Dry-run mode enabled"
        fi

        for RESOURCE_DIR in "$BASE_DIR"/*; do
          [ -d "$RESOURCE_DIR" ] || continue
          RESOURCE=$(basename "$RESOURCE_DIR")
          HOSTS_DIR="$RESOURCE_DIR/hosts"
          [ -d "$HOSTS_DIR" ] || continue

          echo "Dusting off resource: $RESOURCE"
          changed=false

          # Step 1: Check each host
          for HOST_DIR in "$HOSTS_DIR"/*; do
            [ -d "$HOST_DIR" ] || continue
            HOST=$(basename "$HOST_DIR")
            CURR="$HOST_DIR/curr"
            PREV="$HOST_DIR/prev"

            echo "  Checking resource $RESOURCE on host $HOST"
            if [ ! -f "$CURR" ]; then
              continue
            fi

            if [ ! -f "$PREV" ]; then
              if $DRY_RUN; then
                echo "[dry-run] Would copy $CURR to $PREV (prev missing)"
              else
                cp "$CURR" "$PREV"
              fi
              continue
            fi

            if ! cmp -s "$CURR" "$PREV"; then
              echo "Resources changed on host $HOST"
              changed=true
              if $DRY_RUN; then
                echo "[dry-run] Would update $PREV from $CURR (changed)"
              else
                cp "$CURR" "$PREV"
              fi
            fi
          done

          # Step 3: Skip if no change
          if ! $changed; then
            continue
          fi

          echo "Resource $RESOURCE generation changed"

          # Step 3: Run list action
          LIST_ACTION="$RESOURCE_DIR/actions/list"
          STALE_LIST="/tmp/dustman-''${RESOURCE}-''${TIMESTAMP}-list-stale"
          if [ -x "$LIST_ACTION" ]; then
            if $DRY_RUN; then
              echo "[dry-run] Would execute $LIST_ACTION and save to $STALE_LIST"
              touch "$STALE_LIST"
            else
              "$LIST_ACTION" > "$STALE_LIST"
            fi
          else
            echo "List action script not executable: $LIST_ACTION" >&2
            continue
          fi

          # Step 4: Remove lines in curr files from stale list
          for HOST_DIR in "$HOSTS_DIR"/*; do
            [ -d "$HOST_DIR" ] || continue
            CURR="$HOST_DIR/curr"
            [ -f "$CURR" ] || continue

            if $DRY_RUN; then
              echo "[dry-run] Would filter lines from $CURR out of $STALE_LIST"
            else
              grep -vxFf "$CURR" "$STALE_LIST" > "''${STALE_LIST}.tmp" && mv "''${STALE_LIST}.tmp" "$STALE_LIST" || true
            fi
          done

          # Step 5: Shift generations
          mkdir -p "$RESOURCE_DIR/generations"
          for ((i=GENERATIONS-1; i>=1; i--)); do
            OLD_GEN="$RESOURCE_DIR/generations/gen-$i"
            NEW_GEN="$RESOURCE_DIR/generations/gen-$((i+1))"
            touch "$OLD_GEN" "$NEW_GEN"

            if $DRY_RUN; then
              echo "[dry-run] Would append matching lines from $OLD_GEN to $NEW_GEN"
            else
              grep -Fxf "$STALE_LIST" "$OLD_GEN" > "$NEW_GEN" || true
            fi
          done

          # Step 6: Copy current stale list to gen-1
          if $DRY_RUN; then
            echo "[dry-run] Would copy $STALE_LIST to $RESOURCE_DIR/generations/gen-1"
          else
            cp "$STALE_LIST" "$RESOURCE_DIR/generations/gen-1"
          fi

          # Step 7: Run clean action
          CLEAN_ACTION="$RESOURCE_DIR/actions/clean"
          FINAL_GEN="$RESOURCE_DIR/generations/gen-''${GENERATIONS}"
          if [ -x "$CLEAN_ACTION" ]; then
            if $DRY_RUN; then
              echo "[dry-run] Would execute $CLEAN_ACTION with $FINAL_GEN"
            else
              echo "Pruning the following resources:"
              cat $FINAL_GEN
              "$CLEAN_ACTION" "$FINAL_GEN"
            fi
          else
            echo "Clean action script not executable: $CLEAN_ACTION" >&2
          fi

          # Step 9: Run update action
          UPDATE_ACTION="$RESOURCE_DIR/actions/update"
          if [ -x "$UPDATE_ACTION" ]; then
            if $DRY_RUN; then
              echo "[dry-run] Would execute $UPDATE_ACTION"
            else
              "$UPDATE_ACTION"
            fi
          else
            echo "Update action script not executable: $UPDATE_ACTION" >&2
          fi

          # Step 9: Cleanup
          if $DRY_RUN; then
            echo "[dry-run] Would delete $STALE_LIST and $FINAL_GEN"
          else
            rm -f "$STALE_LIST" "$FINAL_GEN"
          fi
        done

      '');

      dustmanPolkitRule = ''
        polkit.addRule(function(action, subject) {
          if (
            action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "dustman.service" &&
            subject.user == "cacher"
          ) {
            return polkit.Result.YES;
          }
        });
      '';
    in lib.mkIf
      (config.resourceCache.enable &&
        (config.resourceCache.role == "server" ||
          config.resourceCache.role == "both"))
      {
        environment.systemPackages = [
          pkgs.util-linux
          pkgs.gnugrep
          pkgs.rsync

          dustman
        ];

        security.polkit.enable = true;

        # Ensure the directory exists
        systemd.tmpfiles.rules = [
          "d /var/lib/dustman 0755 cacher cacher - -"
        ];

        systemd.timers.dustman = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };

        systemd.services.dustman = {
          description = "Run dustman script daily";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${dustman}/bin/dustman";
          };
        };

        environment.etc."polkit-1/rules.d/50-allow-cacher-dustman.rules".text = dustmanPolkitRule;

        # Open firewall port
        networking.firewall.allowedTCPPorts = [ 4647 ];

        users = {
          groups."cacher" = { };

          users."cacher" = {
            name = "cacher";
            group = "cacher";
            isNormalUser = true;
            initialPassword = null;

            openssh.authorizedKeys.keys = [ config.resourceCache.credentials.publicKey ];
          };
        };

      })
    ##################################################
    # Client Configuration: Common
    ##################################################
    (lib.mkIf
      (config.resourceCache.enable &&
        (config.resourceCache.role == "client" ||
          config.resourceCache.role == "both"))
      {
        # Anything?
      })
    ##################################################
    # Server Configuration: Nix Resource
    ##################################################
    (
      let
        cacheDir = "/srv/cache/nix";
        nix-list-cache = (pkgs.writeShellScriptBin "nix-list-cache" ''
          ${pkgs.findutils}/bin/find ${cacheDir}/store -maxdepth 1 -mindepth 1 -printf "/nix/store/%f\n"
        '');
        nix-clean-cache = (pkgs.writeShellScriptBin "nix-clean-cache" ''
          NIX_STORE_DIR=${cacheDir} nix-store --delete /nix/store/
        '');

        nix-update-cache = (pkgs.writeShellScriptBin "nix-update-cache" ''
          
        '');
      in
      lib.mkIf
        (config.resourceCache.enable &&
          (config.resourceCache.role == "server" ||
            config.resourceCache.role == "both") &&
          config.resourceCache.resources.nix.enable)
        {

          environment.etc."nix-cache/nix.conf".text = ''
            store = /srv/cache/nix/store
            sandbox = false
            trusted-users = root, cacher
          '';

          systemd.tmpfiles.rules = [
            "d ${cacheDir} 0755 root root - -"
            # "d ${cacheDir}/store 0755 root root - -"
            # "d ${cacheDir}/var/nix 0755 root root - -"
            # "d ${cacheDir}/var/nix/daemon-socket 0755 root root - -"

            "A ${cacheDir} - - - - user::rwx"
            "A ${cacheDir} - - - - group::r-x"
            "A ${cacheDir} - - - - mask::rwx"

            # Store path
            "A+ ${cacheDir} - - - - user:cacher:rwx"
            "A+ ${cacheDir} - - - - group:cacher:r-x"
            "A+ ${cacheDir} - - - - user:ncps:rwx"
            "A+ ${cacheDir} - - - - group:ncps:r-x"

            "d /var/lib/dustman/nix 0755 cacher cacher - -"
            "d /var/lib/dustman/nix/hosts 0755 cacher cacher - -"
            "d /var/lib/dustman/nix/actions 0755 cacher cacher - -"

            "L+ /var/lib/dustman/nix/actions/list - - - - ${nix-list-cache}/bin/nix-list-cache"
            "L+ /var/lib/dustman/nix/actions/clean - - - - ${nix-clean-cache}/bin/nix-clean-cache"
            "L+ /var/lib/dustman/nix/actions/update - - - - ${nix-update-cache}/bin/nix-update-cache"
          ];

          services.ncps = {
            enable = true;

            logLevel = "debug";

            server.addr = "0.0.0.0:5001";

            upstream = {
              caches = [ "https://cache.nixos.org" ];
            };

            cache = {
              hostName = "pxe_server";
              dataPath = "/srv/cache/nix";
            };
          };

          # services.harmonia = {
          #   enable = true;
          #   settings = {
          #     bind = "0.0.0.0:5001";
          #     real_nix_store = "/srv/cache/nix/store";
          #     virtual_nix_store = "/nix/store";
          #   };
          # };
          # systemd.services.harmonia.environment = {
          #   RUST_LOG = "debug";
          #   # NIX_STORE_DIR = "/srv/cache/nix/store";
          # };
        }
    )
    ##################################################
    # Client Configuration: Nix Resource
    ##################################################
    (
      let
        cacheServer = "192.168.1.5";
        cacheDir = "/srv/cache/nix";
        cacherIdentityFile = config.resourceCache.credentials.privateKey;
        nix-push-cache = (pkgs.writeShellScriptBin "nix-push-cache" ''
          LOCAL_CACHE_LIST=/tmp/nix-$(date +%s)-cache-list
          REMOTE_CACHE_DIR=/var/lib/dustman/nix/hosts/$(hostname)

          NIX_SSHOPTS="-i ${cacherIdentityFile}" \
            ${pkgs.nix}/bin/nix copy --substitute-on-destination \
            --no-check-sigs \
            --to ssh-ng://cacher@${cacheServer}?remote-store=${cacheDir} \
            /run/current-system
        
          ${pkgs.nix}/bin/nix path-info --recursive /run/current-system > $LOCAL_CACHE_LIST
          ${pkgs.openssh}/bin/ssh -i ${cacherIdentityFile} \
            cacher@${cacheServer} \
            "mkdir -p $REMOTE_CACHE_DIR"
          ${pkgs.openssh}/bin/scp -i ${cacherIdentityFile} \
            $LOCAL_CACHE_LIST \
            cacher@${cacheServer}:$REMOTE_CACHE_DIR/curr
        
          rm $LOCAL_CACHE_LIST
        '');
      in
      lib.mkIf
        (config.resourceCache.enable &&
          (config.resourceCache.role == "client" ||
            config.resourceCache.role == "both") &&
          config.resourceCache.resources.nix.enable)
        {
          nix.settings = {
            substituters = lib.mkBefore [
              "http://192.168.1.5:5001?priority=10"
            ];

            experimental-features = [ "nix-command" ];
          };

          environment.systemPackages = [
            nix-push-cache
          ];
        }
    )
    ##################################################
    # Server Configuration: Pacman Resource
    ##################################################
    (
      let
        cacheDir = "/srv/cache/pacman";
        pacman-list-cache = (pkgs.writeShellScriptBin "pacman-list-cache" ''
          ls ${cacheDir}
        '');
        pacman-clean-cache = (pkgs.writeShellScriptBin "pacman-clean-cache" ''
          #!/usr/bin/env bash

          set -euo pipefail

          # Check for input argument
          if [ "$#" -ne 1 ]; then
            echo "Usage: $0 <file-with-list-of-files-to-delete>"
            exit 1
          fi

          LIST_FILE="$1"

          # Check that the file exists
          if [ ! -f "$LIST_FILE" ]; then
            echo "Error: File '$LIST_FILE' not found"
            exit 1
          fi

          # Process each line (file path)
          while IFS= read -r file || [ -n "$file" ]; do
            # Skip empty lines or comments
            [[ -z "$file" || "$file" =~ ^# ]] && continue
            
            if [ -f "${cacheDir}/$file" ]; then
              echo "Removing file: $file"
              rm -f ${cacheDir}/"$file"
            else
              echo "Warning: File not found or not a regular file: $file"
            fi
          done < "$LIST_FILE"

        '');

        pacman-update-cache = (pkgs.writeShellScriptBin "pacman-update-cache" ''
          # pushd ${cacheDir}
          #   repo-add chiliahedron.wtf.db.tar.gz *.pkg.tar.zst
          # popd
        '');
      in
      lib.mkIf
        (config.resourceCache.enable &&
          (config.resourceCache.role == "server" ||
            config.resourceCache.role == "both") &&
          config.resourceCache.resources.pacman.enable)
        {
          environment.systemPackages = [
            pkgs.pacman
          ];

          # Enable nginx
          services.nginx = {
            enable = true;
            
            # Use Google DNS and IPv4 only
            appendHttpConfig = ''
              resolver 8.8.8.8 8.8.4.4 ipv6=off;
            '';

            # Define upstream mirrors
            upstreams."mirrors".servers = {
              "127.0.0.1:8001" = {};
              "127.0.0.1:8002" = { backup = true; };
              "127.0.0.1:8003" = { backup = true; };
            };

            virtualHosts = {
              # Main caching proxy server
              "0.0.0.0:4647" = {
                listen = [{ addr = "0.0.0.0"; port = 4647; }];
                root = "${cacheDir}";
                extraConfig = ''
                  autoindex on;
                '';
                locations = {
                  # Passthrough for db, sig, files
                  "~ \\.(db|sig|files)$" = {
                    proxyPass = "http://mirrors$request_uri";
                  };

                  # Serve cached packages or fall back to upstream
                  "~ \\.tar\\.(xz|zst)$" = {
                    tryFiles = "$uri @pkg_mirror";
                  };

                  # Upstream mirror fallback
                  "@pkg_mirror" = {
                    extraConfig = ''
                      proxy_store on;
                      proxy_redirect off;
                      proxy_store_access user:rw group:rw all:r;
                      proxy_next_upstream error timeout http_404;
                      proxy_pass http://mirrors$request_uri;
                    '';
                  };
                };
              };

              # Upstream mirror 1
              "mirror1.internal" = {
                listen = [{ addr = "127.0.0.1"; port = 8001; }];
                locations."/" = {
                  proxyPass = "http://mirror.osbeck.com/archlinux$request_uri";
                };
              };

              # Upstream mirror 2
              "mirror2.internal" = {
                listen = [{ addr = "127.0.0.1"; port = 8002; }];
                locations."/" = {
                  proxyPass = "http://arch.mirror.constant.com$request_uri";
                };
              };

              # Upstream mirror 3
              "mirror3.internal" = {
                listen = [{ addr = "127.0.0.1"; port = 8003; }];
                locations."/" = {
                  proxyPass = "http://america.mirror.pkgbuild.com$request_uri";
                };
              };
            };
          };

          systemd.tmpfiles.rules = [
            "d ${cacheDir} 0755 nginx nginx - -"
            "a ${cacheDir} - - - - user::rwx"
            "a ${cacheDir} - - - - group::r-x"
            "a ${cacheDir} - - - - mask::rwx"
            "a+ ${cacheDir} - - - - user:cacher:rwx"
            "a+ ${cacheDir} - - - - group:cacher:rwx"

            "d /var/lib/dustman/pacman 0755 cacher cacher - -"
            "d /var/lib/dustman/pacman/hosts 0755 cacher cacher - -"
            "d /var/lib/dustman/pacman/actions 0755 cacher cacher - -"

            "L+ /var/lib/dustman/pacman/actions/list - - - - ${pacman-list-cache}/bin/pacman-list-cache"
            "L+ /var/lib/dustman/pacman/actions/clean - - - - ${pacman-clean-cache}/bin/pacman-clean-cache"
            "L+ /var/lib/dustman/pacman/actions/update - - - - ${pacman-update-cache}/bin/pacman-update-cache"
          ];
        }
    )
  ];
}
