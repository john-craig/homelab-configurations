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
    python3
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