# reuski/nix

## Install

```sh
sudo -i
rfkill unblock all
nmcli device wifi connect "SSID" password "PASSWORD"
curl -L https://github.com/reuski/nix/raw/main/install.sh | sh
```

## Password hash

```sh
set tmp $(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
systemd-firstboot --root="$tmp" --prompt-root-password --force --welcome=no
chmod u+r "$tmp/etc/shadow"
awk -F: '$1 == "root" { print $2 }' "$tmp/etc/shadow"
```

## Rebuild

```sh
git clone https://github.com/reuski/nix ~/nix
sudo nixos-rebuild switch --flake ~/nix#hiisi
```
