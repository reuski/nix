{
  description = "personal systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

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

    heimdash = {
      url = "github:reuski/heimdash";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
