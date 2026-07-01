#!/usr/bin/env python3
"""Verify modules/hosts/<host>/_*.nix files are only reached from their own host.

Private per-host wiring (files prefixed `_`) is a documented convention
(AGENTS.md), not a Nix-enforced one: nothing stops a path expression from
reaching into another host's directory. Same-host imports always use a bare
`./_name.nix` relative path, which can never resolve outside the importing
file's own directory, so the only way to reach a private file from elsewhere
is to spell out its host directory. This flags any such path.
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HOSTS_DIR = os.path.join(ROOT, "modules", "hosts")
ALL_NIX = glob.glob(os.path.join(ROOT, "**", "*.nix"), recursive=True)
REACH_IN = re.compile(r"hosts/([A-Za-z0-9-]+)/(_[A-Za-z0-9-]+\.nix)")


def main():
    errors = 0
    for path in sorted(ALL_NIX):
        with open(path) as f:
            text = f.read()
        for m in REACH_IN.finditer(text):
            host, fname = m.group(1), m.group(2)
            if os.path.dirname(path) != os.path.join(HOSTS_DIR, host):
                rel = os.path.relpath(path, ROOT)
                print(f"FAIL {rel}: reaches into {host}'s private {fname} from outside its directory")
                errors += 1
    if errors:
        print(f"\n{errors} cross-host private import(s). `_*.nix` files may only be imported by their own host.")
        return 1
    print("all private host modules stay within their own host directory")
    return 0


if __name__ == "__main__":
    sys.exit(main())
