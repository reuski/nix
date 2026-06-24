{ ... }:
{
  flake.modules.nixos.plasma =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) getBin getExe';
    in
    {
      services.greetd = {
        enable = true;
        settings.initial_session = {
          command = getExe' pkgs.kdePackages.plasma-workspace "startplasma-wayland";
          user = config.profile.username;
        };
      };

      services.desktopManager.plasma6 = {
        enable = true;
        enableQt5Integration = false;
      };

      programs.kde-pim.enable = false;
      services.orca.enable = false;

      environment.plasma6.excludePackages =
        with pkgs.kdePackages;
        [
          ark
          aurorae
          baloo-widgets
          discover
          dolphin-plugins
          elisa
          ffmpegthumbs
          kate
          khelpcenter
          konsole
          krdp
          ktexteditor
          kwin-x11
          okular
          plasma-browser-integration
          plasma-workspace-wallpapers
        ]
        ++ [ (getBin qttools) ];

      environment.systemPackages = with pkgs; [
        haruna
        p7zip
      ];

      environment.sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
      };
    };
}
