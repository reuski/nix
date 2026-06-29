{ lib, ... }:
{
  options.fontSet = {
    packages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default =
        pkgs: with pkgs; [
          nerd-fonts.hack
          inter
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
        ];
      readOnly = true;
    };

    defaultFonts = lib.mkOption {
      type =
        with lib.types;
        submodule {
          options = {
            sansSerif = lib.mkOption { type = listOf str; };
            serif = lib.mkOption { type = listOf str; };
            monospace = lib.mkOption { type = listOf str; };
            emoji = lib.mkOption { type = listOf str; };
          };
        };
      default = {
        sansSerif = [
          "Inter"
          "Noto Sans"
          "Noto Sans CJK JP"
        ];
        serif = [ "Noto Serif" ];
        monospace = [
          "Hack Nerd Font"
          "Noto Sans Mono"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
      readOnly = true;
    };
  };
}
