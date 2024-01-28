{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

  let
    python-packages = ps: with ps; [
      requests
      docker
    ];
  in
  environment.systemPackages = with pkgs; [
    smartmontools
    nano
    curl
    git
    (python3.withPackages(ps: with ps; [
      requests
      urllib3
      websocket-client
      (pkgs.python3Packages.docker.overrideAttrs(oldAttrs: rec {
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
          (pkgs.python3Packages.docker.overrideAttrs(oldAttrs: rec {
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

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  networking.hostName = "homeserver1";

  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users = {
    mutableUsers = true;
    users."evak" = {
      isNormalUser = true;
      home = "/home/evak";
      initialPassword = null;
      extraGroups = [ "wheel" "docker" ];

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5QNL0MP8yr7OD5rt4PpnL4Go++4rdmLFhhA5ypdpLbwfXqVEKOBnjxSn4Ux0BtHk8cIK5TT9wcigx9gLKaVX2aDSROITz5DMy2EuR09/kBp8xbaAeZQgyDB0C8YHPclPBN/25krDJNocWbJTnmBSwswXYJWGMUQZxfPMUyql3jy2fcxKUg39ATz9Qe9CmJpiBVGgTva0QpNWteTHOn7zwoHDhlIYCUygR/+X9LJCv7TvDPWaeYe9Z4+q58FMt9njTFAY9mXpa2qataIjk1KwoJWs2a8/vW2kYzbdOXH8KVxZuEpqgr4HCF+qdnFbuLtUfCFRKmCr3EI/+qPtUulUggusPm4d9tkfXlLytmydX7u4wJeOwYzsbtMLOPIOmGI8Q+jQUpc9zgbd34nat8LdD+vIayjpv8fU5lziaVVvkVP6EBF4UGGo/K0cdK8GGPoODJfUrNSr5m0Rh9IFHCp5QCvYxhOn4RXtIenx+0D9Am06Ab2G8S53l8yZwuMy7NBM=" 
      ];
    };
  };

  security.sudo.extraRules = [
    { 
      users = [ "evak" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  fileSystems."/srv" =
    { device = "/dev/disk/by-uuid/f5082114-527a-4439-befc-11740365987e";
      fsType = "xfs";
    };
}