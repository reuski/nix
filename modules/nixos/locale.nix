{ ... }:
{
  flake.modules.nixos.locale =
    { config, pkgs, ... }:
    {
      time.timeZone = config.profile.timeZone;

      i18n.defaultLocale = config.profile.locale.default;
      i18n.extraLocaleSettings = {
        LC_TIME = config.profile.locale.regional;
        LC_MEASUREMENT = config.profile.locale.regional;
        LC_MONETARY = config.profile.locale.regional;
        LC_PAPER = config.profile.locale.regional;
        LC_NUMERIC = config.profile.locale.regional;
      };

      i18n.supportedLocales = [
        "${config.profile.locale.default}/UTF-8"
        "${config.profile.locale.regional}/UTF-8"
      ];

      services.xserver.xkb = {
        inherit (config.profile.keyboard)
          layout
          variant
          model
          options
          ;
      };

      console = {
        keyMap = config.profile.keyboard.layout;
        font = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
      };
    };
}
