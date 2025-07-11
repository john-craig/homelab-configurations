{ config, pkgs, lib, ... }:

let
  installerName = "serverinstall_76_199";
  serverInstallScript = pkgs.fetchurl {
    url = "https://api.feed-the-beast.com/v1/modpacks/public/modpack/76/199/server/linux";
    hash = "sha256-TZfaef9Rdbc1XeSLRY8DIYuUw8v16cgVvNGYvKkSYxg="; # Replace after first build
    name = "${installerName}";
  };

  ftbDir = "/var/lib/ftbserver";
in
{
  users.users.ftbserver = {
    isSystemUser = true;
    home = ftbDir;
    group = "ftbserver";
    createHome = true;
  };

  users.groups.ftbserver = {};

  systemd.services.ftbserver = {
    description = "FTB Ultimate Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [
      pkgs.openjdk8
      pkgs.bash
      pkgs.curl
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];

    serviceConfig = {
      User = "ftbserver";
      Group = "ftbserver";
      WorkingDirectory = ftbDir;
      ExecStart = "${ftbDir}/start.sh";
      Restart = "always";
      Environment = "JAVA_HOME=${pkgs.openjdk8}";
    };

    preStart = ''
      cd ${ftbDir}

      # Download the patched java.security
      curl -fsSL https://pastebin.com/raw/EmeF3zrW -o java.security

      if [ ! -f start.sh ]; then
        cp ${serverInstallScript} ./${installerName} || true
        chmod +x ./${installerName} || true
        ./${installerName} -auto -no-java
        echo "eula=true" > eula.txt
        chmod +x start.sh || true
      fi

      # Patch start.sh with -Djava.security.properties=java.security
      if ! grep -q "Djava.security.properties=java.security" start.sh; then
        sed -i 's|"java" -jar |"java" -Djava.security.properties=java.security -jar |' start.sh
      fi
    '';
  };

  environment.systemPackages = with pkgs; [
    curl
    openjdk8
  ];

  networking.firewall.allowedTCPPorts = [ 25565 ];
}
