#!/bin/sh
set -eu

FLAKE="${FLAKE:-github:reuski/nix/main}"
[ -f flake.nix ] && [ "$FLAKE" = "github:reuski/nix/main" ] && FLAKE="."

export NIX_CONFIG="${NIX_CONFIG:-experimental-features = nix-command flakes
accept-flake-config = true
download-buffer-size = 67108864}"

die() {
  printf '%s\n' "error: $*" >&2
  exit 1
}

has() {
  command -v "$1" >/dev/null 2>&1
}

need() {
  has "$1" || die "missing command: $1"
}

load_nix() {
  if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [ -n "${HOME:-}" ] && [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
}

ensure_nix() {
  load_nix
  has nix && return
  need curl
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm
  load_nix
  has nix || die "nix not found; open a new shell and rerun"
}

load_brew() {
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
}

install_nixos_media() {
  host="$1"
  [ "$(uname -s)" = Linux ] || die "$host requires Linux"
  [ "$(id -u)" -eq 0 ] || die "run as root from the NixOS installer"
  [ -e /etc/NIXOS ] || die "run from the NixOS installer"
  need nix
  need nixos-install
  nix run github:nix-community/disko -- --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE#$host"
  nixos-install --flake "$FLAKE#$host" --no-root-passwd
}

ensure_brew() {
  load_brew
  has brew && return
  need curl
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew
  has brew || die "brew not found; open a new shell and rerun"
}

usage() {
  cat >&2 <<EOF
usage: install.sh <host>

hosts:
  abraxas    Apple Silicon MacBook
  hiisi      NixOS laptop (run as root from live ISO)
  shodan     UpCloud Starter VPS (run as root from NixOS install media)
EOF
  exit 2
}

case "${1:-}" in
  abraxas)
    [ "$(uname -s)" = Darwin ] || die "abraxas requires macOS"
    [ "$(id -u)" -ne 0 ] || die "run as your macOS user"
    ensure_nix
    ensure_brew
    nix run github:nix-darwin/nix-darwin -- switch --flake "$FLAKE#abraxas"
    ;;
  hiisi)
    install_nixos_media hiisi
    ;;
  shodan)
    install_nixos_media shodan
    ;;
  *)
    usage
    ;;
esac
