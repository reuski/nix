{ ... }:
{
  flake.modules.nixos.power =
    { lib, ... }:
    {
      services.power-profiles-daemon.enable = true;
      services.tlp.enable = lib.mkForce false;

      services.logind = {
        lidSwitch = "suspend";
        lidSwitchExternalPower = "suspend";
        lidSwitchDocked = "ignore";
      };

      services.fwupd.enable = true;
      services.upower.enable = true;
    };
}
