{ ... }:
{
  flake.modules.nixos.headless =
    { pkgs, ... }:
    {
      documentation.enable = false;
      programs.command-not-found.enable = false;
      programs.nano.enable = false;
      fonts = {
        enableDefaultPackages = false;
        packages = [ pkgs.dejavu_fonts.minimal ];
        fontconfig.enable = true;
      };
      xdg.icons.enable = false;
      xdg.mime.enable = false;
      xdg.sounds.enable = false;
      system.disableInstallerTools = true;

      environment.defaultPackages = [ ];
      environment.systemPackages = with pkgs; [
        curl
        dnsutils
        git
        ghostty.terminfo
        jq
        lsof
        ncurses
        rsync
        tcpdump
      ];
    };
}
