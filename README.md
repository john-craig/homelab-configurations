
```
nix-build '<nixpkgs/nixos>' -I nixos-config=./homeserver-usb-image.nix -A config.system.build.isoImage
```

```
sudo dd bs=4M status=progress oflag=sync if=/nix/store/1gyrqxb9mi493qyg9acj3s17dax9wx9v-nixos-24.05pre-git-x86_64-linux.iso/iso/nixos-24.05pre-git-x86_64-linux.iso of=/dev/sde
```

**For SD Images**
```
sudo NIXPKGS_ALLOW_BROKEN=1 NIX_PATH=.. nix-build '<nixpkgs/nixos>' -I nixos-config=./pizero/pizero-sd-image.nix -A config.system.build.sdImage

sudo unzstd /nix/store/p8qxaay3la6kihqyimmsgpw0d4kj0kka-nixos-sd-image-24.05pre-git-armv7l-linux.img-armv7l-unknown-linux-gnueabihf/sd-image/nixos-sd-image-24.05pre-git-armv7l-linux.img.zst -o /dev/sdd
```

```
sudo NIXPKGS_ALLOW_BROKEN=1 NIX_PATH=.. nix-build '<nixpkgs/nixos>' -I nixos-config=./pizero2/pizero-sd-image.nix -A config.system.build.sdImage
```

```
sudo NIXPKGS_ALLOW_BROKEN=1 NIX_PATH=../../../by_language/nix/ ix-build '<nixpkgs/nixos>' -I nixos-config=./key_server/configuration.nix -A config.system.build.sdImage
```

```
sudo NIXPKGS_ALLOW_BROKEN=1 NIX_PATH=$HOME/programming_alt/by_language/nix/ nix-build '<nixpkgs/nixos>' -I nixos-config=s
d-cards/pxe_server/sd-image.nix -A config.system.build.sdImage
```