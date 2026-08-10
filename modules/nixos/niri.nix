{ inputs, ... }:
{
  flake.modules.nixos.niri =
    { lib, pkgs, ... }:
    let
      niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
      niriSession = lib.getExe' niriPackage "niri-session";
      tuigreet = lib.getExe pkgs.tuigreet;
    in
    {
      imports = [ inputs.niri.nixosModules.niri ];

      niri-flake.cache.enable = false;

      nix.settings = {
        substituters = lib.mkAfter [ "https://niri.cachix.org" ];
        trusted-public-keys = lib.mkAfter [
          "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        ];
      };

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

      systemd.tmpfiles.rules = [
        "d /var/cache/tuigreet 0755 greeter greeter -"
      ];
    };
}
