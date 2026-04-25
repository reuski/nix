{
  description = "hiisi laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    inputs@{
      self,
      nixpkgs,
      disko,
      home-manager,
      nixos-hardware,
      niri,
      noctalia,
      vicinae,
      ghostty,
      ...
    }:
    let
      system = "x86_64-linux";

      overlays = [
        (import ./overlays { inherit inputs; })
        niri.overlays.niri
        ghostty.overlays.default
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.hiisi = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self; };
        modules = [
          { nixpkgs.overlays = overlays; }

          disko.nixosModules.disko
          ./hosts/hiisi/disko.nix

          nixos-hardware.nixosModules.lenovo-thinkpad-t480
          ./hosts/hiisi/hardware-configuration.nix

          niri.nixosModules.niri

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              backupFileExtension = "hm-backup";
              users.reuski = import ./home/reuski;
              sharedModules = [
                noctalia.homeModules.default
                vicinae.homeManagerModules.default
              ];
            };
          }

          ./hosts/hiisi
          ./modules/boot.nix
          ./modules/networking.nix
          ./modules/users.nix
          ./modules/locale.nix
          ./modules/audio.nix
          ./modules/graphics.nix
          ./modules/power.nix
          ./modules/niri.nix
          ./modules/nix.nix
          ./modules/fingerprint.nix
        ];
      };

      packages.${system}.helium-browser = pkgs.helium-browser;
      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
