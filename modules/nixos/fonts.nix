{ ... }:
{
  flake.modules.nixos.fonts =
    { pkgs, ... }:
    {
      fonts.enableDefaultPackages = false;
      fonts.packages = with pkgs; [
        nerd-fonts.hack
        noto-fonts-color-emoji
      ];

      fonts.fontconfig.defaultFonts = {
        monospace = [ "Hack Nerd Font" ];
        sansSerif = [ "Hack Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
}
