{ ... }:
{
  flake.modules.nixos.plasma =
    { ... }:
    {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };

      services.desktopManager.plasma6 = {
        enable = true;
        enableQt5Integration = false;
      };

      programs.kdeconnect.enable = true;

      environment.sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
      };
    };
}
