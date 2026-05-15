{ ... }:
{
  flake.modules.nixos.fonts =
    { pkgs, ... }:
    {
      fonts.enableDefaultPackages = false;
      fonts.packages = with pkgs; [
        hack-font
        nerd-fonts.hack
        nerd-fonts.symbols-only
        inter
        noto-fonts
        noto-fonts-color-emoji
      ];

      fonts.fontconfig.defaultFonts = {
        monospace = [ "Hack Nerd Font" ];
        sansSerif = [ "Inter" "Noto Sans" "Noto Color Emoji" ];
        serif = [ "Noto Serif" "Noto Color Emoji" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
}
