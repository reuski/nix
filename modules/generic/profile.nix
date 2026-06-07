{ ... }:
{
  flake.modules.generic.profile =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.profile = {
        username = lib.mkOption { type = lib.types.str; };
        fullName = lib.mkOption { type = lib.types.str; };
        email = lib.mkOption { type = lib.types.str; };
        homeDirectory = lib.mkOption { type = lib.types.str; };
        timeZone = lib.mkOption { type = lib.types.str; };
        sshAuthorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys authorized for profile.username.";
        };
        locale = {
          default = lib.mkOption { type = lib.types.str; };
          regional = lib.mkOption { type = lib.types.str; };
        };
        keyboard = {
          model = lib.mkOption { type = lib.types.str; };
          layout = lib.mkOption { type = lib.types.str; };
          variant = lib.mkOption { type = lib.types.str; };
          options = lib.mkOption { type = lib.types.str; };
        };
        colors.gruvbox = lib.mkOption { type = lib.types.attrsOf lib.types.str; };
      };

      config.profile = {
        username = lib.mkDefault "reuski";
        fullName = lib.mkDefault "reuski";
        email = lib.mkDefault "sami@reuski.dev";
        homeDirectory = lib.mkDefault (
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Users/${config.profile.username}"
          else
            "/home/${config.profile.username}"
        );
        timeZone = lib.mkDefault "Europe/Helsinki";
        sshAuthorizedKeys = lib.mkDefault [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYOhwRvjVJHFoTPD02CCbvnvBUeS1eq1jSmUvfYCmbp sami@reuski.dev"
        ];
        locale = {
          default = lib.mkDefault "en_US.UTF-8";
          regional = lib.mkDefault "fi_FI.UTF-8";
        };
        keyboard = {
          model = lib.mkDefault "pc105";
          layout = lib.mkDefault "fi";
          variant = lib.mkDefault "nodeadkeys";
          options = lib.mkDefault "";
        };
        colors.gruvbox = {
          bg0 = "#282828";
          bg1 = "#3c3836";
          bg2 = "#504945";
          fg1 = "#ebdbb2";
          gray = "#928374";
          red = "#fb4934";
          green = "#b8bb26";
          yellow = "#fabd2f";
          blue = "#83a598";
          purple = "#d3869b";
          aqua = "#8ec07c";
          orange = "#fe8019";
          black = "#1d2021";
          white = "#a89984";
        };
      };
    };
}
