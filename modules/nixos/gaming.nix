{ ... }:
{
  flake.modules.nixos.gaming =
    { config, pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
      };

      powerManagement.cpuFreqGovernor = "performance";

      hardware.steam-hardware.enable = true;
      hardware.uinput.enable = true;
      hardware.graphics.enable32Bit = true;

      users.users.${config.profile.username}.extraGroups = [ "uinput" ];

      environment.systemPackages = [ pkgs.faugus-launcher ];
    };
}
