{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  instawow = pkgs.instawow.overridePythonAttrs (old: {
    version = "0-unstable-${inputs.instawow.shortRev}";
    src = inputs.instawow;
    nativeBuildInputs = with pkgs.python3.pkgs; [
      hatchling
      versioningit
    ];
    postPatch = (old.postPatch or "") + ''
      printf '\n[tool.versioningit]\ndefault-version = "0.dev0+g${inputs.instawow.shortRev}"\n' >> pyproject.toml
    '';
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ pkgs.python3.pkgs.wcwidth ];
    pythonRelaxDeps = [
      "aiohttp"
      "rapidfuzz"
    ];
    pythonImportsCheck = [ "instawow.cli" ];
  });

  protonVariants = {
    CachyOS = pkgs.proton-cachyos;
    GE = pkgs.proton-ge-bin;
  };
in
{
  programs.steam.extraCompatPackages = builtins.attrValues protonVariants;
  environment.systemPackages = [ pkgs.umu-launcher ];

  home-manager.users.${config.profile.username} = {
    home.packages = [ instawow ];

    xdg.configFile."instawow/profiles/__default__/config.json".text = builtins.toJSON {
      profile = "__default__";
      addon_dir = "${config.profile.homeDirectory}/games/windows/wine-prefixes/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";
    };

    xdg.dataFile = lib.mapAttrs' (
      name: package:
      lib.nameValuePair "Steam/compatibilitytools.d/Nix-Proton-${name}" {
        source = package.steamcompattool;
      }
    ) protonVariants;
  };
}
