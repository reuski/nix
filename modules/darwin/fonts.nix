{ ... }:
{
  flake.modules.darwin.fonts =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        hack-font
        nerd-fonts.hack
      ];
    };
}
