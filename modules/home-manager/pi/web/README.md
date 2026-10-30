# Pi web tools

Two read-only tools in the `web` namespace, exposed through codemode as `tools.web_search` and `tools.web_fetch`.

- `web_search` sends one query to the fixed search endpoint and returns five bounded results with engine status. No client-side cloud fallback.
- `web_fetch` takes one explicit `http(s)` URL and returns bounded Markdown, plain text, JSON text, or article Markdown extracted from HTML/XHTML by nixpkgs `trafilatura`. It sends no cookies, credentials, or browser identity, runs no page JavaScript, and does not retry; redirects are followed at most five times, each target revalidated.
- Private-network URLs are allowed; this is not an SSRF sandbox. Results are untrusted static excerpts, not browser-rendered pages.

Limits: search 15 s / 1 MiB / 5 results; fetch 20 s / 2 MiB / 12,000 characters; extractor 5 s inside the fetch deadline; 4 concurrent operations with excess calls rejected. A cancelled or timed-out call waits for the extractor to be killed and reaped before its slot is released.

**Wiring.** `pi.nix` generates `~/.pi/agent/extensions/web/index.ts`, which imports this directory from the Nix store and binds the search endpoint, the interpreter, and `extract.py`.

**Test.** `bun test` installs nothing and skips extraction without `PI_WEB_PYTHON`. Schema checks use Pi's existing TypeBox dependency. Set `PI_NODE_MODULES` to the absolute path of that installation's `node_modules`, then run from the flake root (the temporary copy leaves the checkout untouched):

```sh
PI_WEB_PYTHON=$(nix build --no-link --print-out-paths --impure --expr \
  'let flake = builtins.getFlake (toString ./.);
       pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
   in pkgs.python3.withPackages (ps: [ ps.trafilatura ])')/bin/python3
test -d "${PI_NODE_MODULES:?Set the existing Pi node_modules path}/typebox" || exit 1
test_dir=$(mktemp -d)
cp -R modules/home-manager/pi/web "$test_dir/web"
ln -s "$PI_NODE_MODULES" "$test_dir/node_modules"
(cd "$test_dir/web" && PI_WEB_PYTHON="$PI_WEB_PYTHON" bun test)
```

Measured interpreter closure: 312 MiB (`nix path-info -Sh`). No runtime npm installation or lockfile.
