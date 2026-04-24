{ lib, ... }:
{
  services.power-profiles-daemon.enable = true;
  services.tlp.enable = lib.mkForce false;

  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.upower.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
}
