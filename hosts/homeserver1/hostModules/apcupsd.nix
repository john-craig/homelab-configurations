{ pkgs, lib, config, ... }: {
  config = {
    services.prometheus.exporters.apcupsd = {
      enable = true;
      port = 9162;
      apcupsdAddress = "0.0.0.0:3551";
    };

    services.apcupsd = {
      enable = true;
      configText = ''
        UPSTYPE usb
        UPSCABLE usb
        NISIP 0.0.0.0
        NISPORT 3551
      '';
      hooks = {
        doshutdown = ''
          # Fire a message to Gotify
          API_KEY=$(cat /run/secrets/gotify/notifier/api_key)
          curl -s -S --data '{"message": "'"Home Server on Back-Up Power"'", "title": "'"Home Server Backup Notifier"'", "priority":'"10"', "extras": {"client::display": {"contentType": "text/markdown"}}}' -H 'Content-Type: application/json' "https://gotify.chiliahedron.wtf/message?token=$API_KEY"
        '';
      };
    };
  };
}
