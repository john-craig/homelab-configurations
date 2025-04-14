{ pkgs, lib, config, ... }: {
  options = {
    resourceCache = {
      enable = lib.mkEnableOption "Cache Server services";

      role = lib.mkOption {
        type = lib.types.enum [ "client" "server" "both" ];
        default = "client"; # default value
        description = "Defines whether the configuration is for the client, server, or both.";
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
    (lib.mkIf (config.resourceCache.enable && 
      (config.resourceCache.role == "server" ||
       config.resourceCache.role == "both")) {
      environment.systemPackages = [
        pkgs.util-linux
        pkgs.gnugrep
        pkgs.rsync

        # dustman
        (pkgs.writeShellScriptBin "dustman" ''
          #!/usr/bin/env bash

          set -euo pipefail

          GENERATIONS=3
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

            changed=false

            # Step 1: Check each host
            for HOST_DIR in "$HOSTS_DIR"/*; do
              [ -d "$HOST_DIR" ] || continue
              HOST=$(basename "$HOST_DIR")
              CURR="$HOST_DIR/curr"
              PREV="$HOST_DIR/prev"

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

        '')
      ];

      # Ensure the directory exists
      systemd.tmpfiles.rules = [
        "d /var/lib/dustman 0755 cacher cacher - -"
      ];

      # Open firewall port
      networking.firewall.allowedTCPPorts = [ 4647 ];

      users = {
        groups."cacher" = { };

        users."cacher" = {
          name = "cacher";
          group = "cacher";
          isNormalUser = true;
          initialPassword = null;

          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYteO0QiyhHrDeoxJ0O2lq83VGvZnIHxkHpxCyb34mR"
          ];
        };
      };

    })
    ##################################################
    # Server Configuration: Nix Resource
    ##################################################
    (let 
        cacheDir = "/srv/cache/nix";
        nix-list-cache = (pkgs.writeShellScriptBin "nix-list-cache" ''
          ls ${cacheDir}
        '');
        nix-clean-cache = (pkgs.writeShellScriptBin "nix-clean-cache" ''
          
        '');

        nix-update-cache = (pkgs.writeShellScriptBin "nix-update-cache" ''
          
        '');
    in lib.mkIf (config.resourceCache.enable &&
       (config.resourceCache.role == "server" ||
        config.resourceCache.role == "both") &&
        config.resourceCache.resources.nix.enable) {
      environment.systemPackages = [
        
      ];

      # Create a user and group for running the cache
      users.users.nix-serve = {
        isSystemUser = true;
        group = "nix-serve";
      };

      users.groups.nix-serve = {};

      services.nix-serve = {
        enable = true;
        bindAddress = "0.0.0.0";  
        port = 5001;        
        package = pkgs.nix-serve-ng;
      };
      # Hack to override the location of the storage directory
      systemd.services.nix-serve.environment = {
        NIX_STORE_DIR = cacheDir;
      };

      systemd.tmpfiles.rules = [
        "d ${cacheDir} 0755 nix-serve nix-serve -"
        "a ${cacheDir} - - - - user::rwx"
        "a ${cacheDir} - - - - group::r-x"
        "a ${cacheDir} - - - - mask::rwx"
        "a+ ${cacheDir} - - - - user:cacher:rwx"
        "a+ ${cacheDir} - - - - group:cacher:rwx"

        "d /var/lib/dustman/nix 0755 cacher cacher - -"
        "d /var/lib/dustman/nix/hosts 0755 cacher cacher - -"
        "d /var/lib/dustman/nix/actions 0755 cacher cacher - -"

        "L+ /var/lib/dustman/nix/actions/list - - - - ${nix-list-cache}/bin/nix-list-cache"
        "L+ /var/lib/dustman/nix/actions/clean - - - - ${nix-clean-cache}/bin/nix-clean-cache"
        "L+ /var/lib/dustman/nix/actions/update - - - - ${nix-update-cache}/bin/nix-update-cache"
      ];
    })
    ##################################################
    # Server Configuration: Pacman Resource
    ##################################################
    (let 
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
          pushd ${cacheDir}
            repo-add chiliahedron.wtf.db.tar.gz *.pkg.tar.zst
          popd
        '');
    in lib.mkIf (config.resourceCache.enable &&
       (config.resourceCache.role == "server" ||
        config.resourceCache.role == "both") &&
        config.resourceCache.resources.pacman.enable) {
      environment.systemPackages = [
        pkgs.pacman
      ];


      # Enable nginx
      services.nginx = {
        enable = true;
        virtualHosts."0.0.0.0:4647" = {
          root = "${cacheDir}";
          listen = [{
            addr = "0.0.0.0";
            port = 4647;
          }];
          locations."/" = {
            extraConfig = ''
              autoindex on;
            '';
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
    })
  ];
}