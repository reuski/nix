#!/bin/sh
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Root required"; exit 1; }

export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true
download-buffer-size = 536870912"

URI="github:reuski/nix#hiisi"

nix run github:nix-community/disko -- --mode destroy,format,mount --yes-wipe-all-disks --flake "$URI" && \
nixos-install --flake "$URI" --no-root-passwd && \
echo "Reboot."
