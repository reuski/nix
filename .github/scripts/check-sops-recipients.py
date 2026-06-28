#!/usr/bin/env python3
"""Verify each secrets/*.yaml recipient set matches .sops.yaml creation_rules.

Keyless: reads only embedded `sops.age[].recipient[]` values and compares them
against the recipients declared by `.sops.yaml` for the matching path_regex.
Catches under-rekeyed (stale) and over-scoped recipient drift without any
private key material.

Pure stdlib: `.sops.yaml` anchor aliases and sops metadata are regular and
owned by this repo, so a tolerant line parser suffices (no YAML dependency).
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RULES = os.path.join(ROOT, ".sops.yaml")
SECRETS = os.path.join(ROOT, "secrets", "*.yaml")
AGE = re.compile(r"age1[0-9a-z]+")


def load_anchors(text):
    """Map `&name` -> age key, from the top-level `keys:` list."""
    anchors = {}
    for m in re.finditer(r"&(\S+)\s+(age1[0-9a-z]+)", text):
        anchors[m.group(1)] = m.group(2)
    return anchors


def resolve(token, anchors):
    """A `*name` alias resolves to its age key; bare age keys pass through."""
    if token.startswith("*"):
        return anchors.get(token[1:], token)
    if AGE.fullmatch(token):
        return token
    return None


def expected(path, text):
    """Return (set_of_recipients, matched_regex) for a secret file path."""
    rel = os.path.relpath(path, ROOT)
    anchors = load_anchors(text)
    cr = re.search(r"^creation_rules:\s*\n(.*)", text, re.DOTALL)
    body = cr.group(1) if cr else text
    marks = [m.start() for m in re.finditer(r"^\s*-\s+path_regex:\s*", body, re.MULTILINE)]
    marks.append(len(body))
    for i in range(len(marks) - 1):
        chunk = body[marks[i] : marks[i + 1]]
        rm = re.search(r"path_regex:\s*['\"]?(.+?)['\"]?\s*$", chunk, re.MULTILINE)
        if not rm:
            continue
        regex = rm.group(1).strip()
        if not re.search(regex, rel):
            continue
        keys = set()
        for tok in re.findall(r"(\*[A-Za-z0-9_-]+|age1[0-9a-z]+)", chunk):
            r = resolve(tok, anchors)
            if r:
                keys.add(r)
        return keys, regex
    return None, None


def actual(path):
    """Recipient set embedded in a sops file's `sops.age[]` metadata."""
    with open(path) as f:
        lines = f.read().splitlines()
    in_sops = False
    keys = set()
    for line in lines:
        if re.match(r"^sops:\s*$", line):
            in_sops = True
            continue
        if in_sops:
            m = re.search(r"recipient:\s*(age1[0-9a-z]+)", line)
            if m:
                keys.add(m.group(1))
    return keys


def main():
    with open(RULES) as f:
        rules_text = f.read()
    files = sorted(glob.glob(SECRETS))
    if not files:
        print("no secret files found")
        return 0
    errors = 0
    for f in files:
        rel = os.path.relpath(f, ROOT)
        exp, regex = expected(f, rules_text)
        if exp is None:
            print(f"FAIL {rel}: no creation_rule matches")
            errors += 1
            continue
        act = actual(f)
        if act != exp:
            missing, extra = exp - act, act - exp
            print(f"FAIL {rel}: recipient mismatch (rule `{regex}`)")
            if missing:
                print(f"  missing: {sorted(missing)}")
            if extra:
                print(f"  extra:   {sorted(extra)}")
            errors += 1
        else:
            print(f"ok   {rel} ({len(act)} recipients)")
    if errors:
        print(f"\n{errors} file(s) drifted. Fix: sops updatekeys --yes <file>")
        return 1
    print("\nall recipient sets match .sops.yaml")
    return 0


if __name__ == "__main__":
    sys.exit(main())
