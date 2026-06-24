{ lib, ... }:
{
  networking.wireless.iwd.enable = lib.mkForce false;
}
