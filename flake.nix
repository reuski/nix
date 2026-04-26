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
          ./modules/dbus.nix
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

      apps.${system}.update-custom = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "update-custom" ''
          PATH=${pkgs.lib.makeBinPath (with pkgs; [ curl jq ])}:$PATH
          set -euo pipefail

          update_release() {
            local repo="$1" file="$2" url_template="$3"
            local latest current url hash sri

            latest=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')
            current=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$file" | head -1)

            [ "$latest" = "$current" ] && { echo "$repo: up to date ($current)"; return 0; }

            url=$(echo "$url_template" | sed "s/{version}/$latest/g")
            hash=$(nix-prefetch-url --type sha256 "$url")
            sri=$(nix hash to-sri --type sha256 "$hash")

            sed -i 's/^  version = ".*";/  version = "'"$latest"'";/' "$file"
            sed -i 's|^    hash = ".*";|    hash = "'"$sri"'";|' "$file"

            echo "$repo: $current -> $latest"
          }

          update_tag() {
            local repo="$1" file="$2" url_template="$3"
            local latest current url hash sri

            latest=$(curl -fsSL "https://api.github.com/repos/$repo/tags?per_page=1" | jq -r '.[0].name')
            current=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$file" | head -1)

            [ "$latest" = "$current" ] && { echo "$repo: up to date ($current)"; return 0; }

            url=$(echo "$url_template" | sed "s/{version}/$latest/g")
            hash=$(nix-prefetch-url --type sha256 "$url")
            sri=$(nix hash to-sri --type sha256 "$hash")

            sed -i 's/^  version = ".*";/  version = "'"$latest"'";/' "$file"
            sed -i 's|^    hash = ".*";|    hash = "'"$sri"'";|' "$file"

            echo "$repo: $current -> $latest"
          }

          update_release "imputnet/helium-linux" \
            "pkgs/helium-browser/default.nix" \
            "https://github.com/imputnet/helium-linux/releases/download/{version}/helium-{version}-x86_64_linux.tar.xz"

          update_tag "uunicorn/python-validity" \
            "pkgs/python-validity/default.nix" \
            "https://github.com/uunicorn/python-validity/archive/refs/tags/{version}.tar.gz"
        ''}/bin/update-custom";
      };
    };
}
