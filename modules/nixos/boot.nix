{ ... }:
{
  flake.modules.nixos.boot = {
    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = 4;
      editor = false;
    };
    boot.loader.efi.canTouchEfiVariables = true;

    boot.initrd.systemd.enable = true;
  };
}
