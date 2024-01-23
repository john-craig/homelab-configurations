
```
nix-build '<nixpkgs/nixos>' -I nixos-config=./homeserver-usb-image.nix -A config.system.build.isoImage
```

```
sudo dd bs=4M status=progress oflag=sync if=/nix/store/1gyrqxb9mi493qyg9acj3s17dax9wx9v-nixos-24.05pre-git-x86_64-linux.iso/iso/nixos-24.05pre-git-x86_64-linux.iso of=/dev/sde
```