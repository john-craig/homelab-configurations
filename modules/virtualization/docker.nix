{ pkgs, lib, config, ... }: {
  options = {
    docker.enable = lib.mkEnableOption "Enable packages for Docker with support for Ansible.";
  };

  config = lib.mkIf config.docker.enable {
    environment.systemPackages = with pkgs; [
      docker
      (python3.withPackages (ps: with ps; [
        requests
        urllib3
        websocket-client
        (pkgs.python3Packages.docker.overrideAttrs (oldAttrs: rec {
          pname = "docker";
          version = "6.1.3";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-qm0XgwBFul7wFo1eqjTTe+6xE5SMQTr/4dWZH8EfmiA=";
          };
        }))
        (buildPythonPackage rec {
          pname = "docker-compose";
          version = "1.29.2";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-TIzZ0h0jdBJ5PRi9MxEASe6a+Nqz/iwhO70HM5WbCbc=";
          };
          doCheck = false;
          propagatedBuildInputs = [
            (pkgs.python3Packages.docker.overrideAttrs (oldAttrs: rec {
              pname = "docker";
              version = "6.1.3";
              src = fetchPypi {
                inherit pname version;
                sha256 = "sha256-qm0XgwBFul7wFo1eqjTTe+6xE5SMQTr/4dWZH8EfmiA=";
              };
            }))
            pkgs.python3Packages.python-dotenv
            pkgs.python3Packages.dockerpty
            pkgs.python3Packages.setuptools
            pkgs.python3Packages.distro
            pkgs.python3Packages.pyyaml
            pkgs.python3Packages.jsonschema
            pkgs.python3Packages.docopt
            pkgs.python3Packages.texttable
          ];
        })
      ]))
    ];
  };
}
