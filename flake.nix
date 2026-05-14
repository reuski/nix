{
  description = "personal systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    download-buffer-size = 536870912;
    extra-substituters = [
      "https://niri.cachix.org"
      "https://noctalia.cachix.org"
      "https://vicinae.cachix.org"
      "https://ghostty.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
    ];
  };

  outputs =
    inputs:
    let
      importTree =
        path:
        let
          entries = builtins.readDir path;
          names = builtins.attrNames entries;
          visible = builtins.filter (name: builtins.match "_.*" name == null) names;
          importEntry =
            name:
            let
              type = entries.${name};
              entry = path + "/${name}";
            in
            if type == "directory" then
              importTree entry
            else if type == "regular" && builtins.match ".*\\.nix" name != null then
              [ entry ]
            else
              [ ];
        in
        builtins.concatLists (map importEntry visible);
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = importTree ./modules;
    };
}
