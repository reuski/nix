{ inputs, ... }:
{
  flake.modules.nixos.niri =
    { lib, pkgs, ... }:
    let
      niriPackage = pkgs.niri-unstable;
      niriSession = lib.getExe' niriPackage "niri-session";
      tuigreet = lib.getExe pkgs.tuigreet;
    in
    {
      imports = [ inputs.niri.nixosModules.niri ];

      niri-flake.cache.enable = false;

      programs.niri = {
        enable = true;
        package = niriPackage;
      };

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${tuigreet} --time --remember --remember-user-session --cmd ${niriSession}";
          user = "greeter";
        };
      };

      xdg.portal.xdgOpenUsePortal = true;
      security.pam.services.greetd.enableGnomeKeyring = true;

      environment.sessionVariables = {
        QT_QPA_PLATFORM = "wayland";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      };

      fonts.enableDefaultPackages = false;
      fonts.packages = with pkgs; [
        nerd-fonts.hack
        nerd-fonts.symbols-only
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        inter
      ];
      fonts.fontconfig.defaultFonts = {
        monospace = [ "Hack Nerd Font" ];
        sansSerif = [
          "Inter"
          "Noto Sans"
          "Noto Color Emoji"
        ];
        serif = [
          "Noto Serif"
          "Noto Color Emoji"
        ];
      };

      systemd.tmpfiles.rules = [
        "d /var/cache/tuigreet 0755 greeter greeter -"
      ];
    };
}
