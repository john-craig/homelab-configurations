{ pkgs, lib, config, ... }: {
  config =
    let
      domain = "chiliahedron.wtf";
    in
    {
      services = {
        headscale = {
          enable = true;
          address = "127.0.0.1";
          port = 8083;

          settings = {
            server_url = "https://headscale.${domain}";
            dns = {
              magic_dns = false;
              # base_domain = "${domain}"; 
            };
            logtail.enabled = false;
          };
        };
      };
    };
}
