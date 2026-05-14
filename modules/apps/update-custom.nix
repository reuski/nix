{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      updateCustom = pkgs.writeShellScriptBin "update-custom" ''
        PATH=${
          pkgs.lib.makeBinPath (
            with pkgs;
            [
              curl
              gnused
              jq
              nix
            ]
          )
        }:$PATH
        set -euo pipefail

        update_version() {
          local latest="$1" file="$2" url_template="$3" current url hash

          current=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$file" | head -1)

          [ "$latest" = "$current" ] && { echo "$file: up to date ($current)"; return 0; }

          url=$(echo "$url_template" | sed "s/{version}/$latest/g")
          hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r .hash)

          sed -i '0,/version = "[^"]*";/s//version = "'"$latest"'";/' "$file"
          sed -i '0,/hash = "[^"]*";/s//hash = "'"$hash"'";/' "$file"

          echo "$file: $current -> $latest"
        }

        update_release() {
          local repo="$1" file="$2" url_template="$3" latest

          latest=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')
          update_version "$latest" "$file" "$url_template"
        }

        update_tag() {
          local repo="$1" file="$2" url_template="$3" latest

          latest=$(curl -fsSL "https://api.github.com/repos/$repo/tags?per_page=1" | jq -r '.[0].name')
          update_version "$latest" "$file" "$url_template"
        }

        update_release "imputnet/helium-linux" \
          "modules/packages/helium-browser.nix" \
          "https://github.com/imputnet/helium-linux/releases/download/{version}/helium-{version}-x86_64_linux.tar.xz"

        update_tag "uunicorn/python-validity" \
          "modules/packages/python-validity.nix" \
          "https://github.com/uunicorn/python-validity/archive/refs/tags/{version}.tar.gz"

        update_release "dj95/zjstatus" \
          "modules/packages/zjstatus.nix" \
          "https://github.com/dj95/zjstatus/releases/download/{version}/zjstatus.wasm"
      '';
    in
    {
      apps.update-custom = {
        type = "app";
        program = pkgs.lib.getExe updateCustom;
      };
    };
}
