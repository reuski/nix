{ ... }:
{
  flake.modules.nixos.power =
    { lib, ... }:
    {
      services.power-profiles-daemon.enable = true;
      services.tlp.enable = lib.mkForce false;

      services.logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
      };

      services.fwupd.enable = true;
      services.upower.enable = true;
    };
}
