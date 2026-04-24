{ pkgs, ... }:
{
  time.timeZone = "Europe/Helsinki";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "fi_FI.UTF-8";
    LC_MEASUREMENT = "fi_FI.UTF-8";
    LC_MONETARY = "fi_FI.UTF-8";
    LC_PAPER = "fi_FI.UTF-8";
    LC_NUMERIC = "fi_FI.UTF-8";
  };

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "fi_FI.UTF-8/UTF-8"
  ];

  console = {
    keyMap = "fi";
    packages = [ pkgs.terminus_font ];
    font = "ter-v24n";
  };
}
