{ pkgs, lib, config, ... }: {
  options = {
    selfhosting = {
      enable = lib.mkEnableOption "self-hosted services";
    };
  };

  config = lib.mkIf config.selfhosting.enable {
    services.gallipedal.v2 = {
      enable = true;
      services = {
        "audiobookshelf".containers."audiobookshelf" = {
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

      proxyConf = {
        internalRules = "HeadersRegexp(`X-Real-Ip`, `(^192\.168\.[0-9]+\.[0-9]+)|(^100\.127\.79\.104)|(^100\.112\.189\.60)|(^100\.69\.200\.65)`)";
        network = "chiliahedron-services";
        tlsResolver = "chiliahedron-resolver";
      };
    };

  };
}