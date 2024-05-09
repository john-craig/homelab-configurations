```
sudo NIXPKGS_ALLOW_BROKEN=1 NIX_PATH=$HOME/programming_alt/by_language/nix/ nix-build '<nixpkgs/nixos>' -I nixos-config=./usb-livecd/installer.nix -A config.system.build.isoImage


```
sudo dd if=/nix/store/sg630a8jpk57maf5qk8yc79blcd5b3d7-nixos-24.05pre-git-x86_64-linux.iso/iso/nixos-24.05pre-git-x86_64-linux.iso of=/dev/sde
```