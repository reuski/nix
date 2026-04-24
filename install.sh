#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run as root.' >&2
  exit 1
fi

NIX_CONFIG='experimental-features = nix-command flakes
accept-flake-config = true
download-buffer-size = 536870912'
export NIX_CONFIG

nix run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --no-deps \
  --flake github:reuski/nix#hiisi

nixos-install \
  --flake github:reuski/nix#hiisi \
  --no-root-passwd

printf '%s\n' 'Install complete. Reboot when ready.' >&2
