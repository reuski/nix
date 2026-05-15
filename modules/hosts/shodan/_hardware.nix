{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
