{ config, lib, ... }:
{
  services.dbus.packages = lib.mkForce [ config.system.path ];
}
