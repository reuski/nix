{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
