{ ... }:
{
  flake.modules.nixos.deploy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.deploy;
      flake = "github:reuski/nix/main";

      pipeline = pkgs.writeShellApplication {
        name = "deploy";
        runtimeInputs = [
          config.nix.package
          pkgs.git
          pkgs.nixos-rebuild
          pkgs.openssh
          pkgs.attic-client
          pkgs.curl
          pkgs.jq
          pkgs.gawk
          pkgs.coreutils
        ];
        text = ''
          rc=0
          report=$(mktemp)
          warns=$(mktemp)
          trap 'rm -f "$report" "$warns"' EXIT

          collect() { grep -iE 'warning|deprecat' "$1" >> "$warns" || true; }

          ${lib.optionalString (cfg.targets != [ ]) ''
            export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

            activate() {
              nixos-rebuild switch --flake "${flake}#$1" \
                --target-host "root@$1" --refresh --option tarball-ttl 0
            }

            reboot_if_stale() {
              ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "root@$1" '
                booted=$(readlink /run/booted-system/{kernel,initrd,kernel-modules})
                built=$(readlink /run/current-system/{kernel,initrd,kernel-modules})
                [ "$booted" = "$built" ] || systemctl reboot'
            }

            ${lib.concatMapStringsSep "\n" (h: ''
              log=$(mktemp)
              if activate ${h} > "$log" 2>&1 || activate ${h} > "$log" 2>&1; then
                reboot_if_stale ${h} || true
              else
                rc=1
                { printf '%s // DEPLOY FAULT\n' ${h}; tail -n 6 "$log"; printf '\n'; } >> "$report"
              fi
              collect "$log"
              rm -f "$log"
            '') cfg.targets}
          ''}

          ${lib.optionalString (cfg.warm != [ ]) ''
            warm() {
              local out
              out=$(nix build "${flake}#nixosConfigurations.$1.config.system.build.toplevel" \
                --refresh --option tarball-ttl 0 --no-link --print-out-paths 2> "$2") || return 1
              attic push "local:${cfg.cache}" "$out" >> "$2" 2>&1
            }

            # shellcheck disable=SC2154
            attic login local http://127.0.0.1:8090 "$(cat "$CREDENTIALS_DIRECTORY/attic-token")"

            ${lib.concatMapStringsSep "\n" (h: ''
              log=$(mktemp)
              if ! warm ${h} "$log"; then
                rc=1
                { printf '%s // BUILD FAULT\n' ${h}; tail -n 6 "$log"; printf '\n'; } >> "$report"
              fi
              collect "$log"
              rm -f "$log"
            '') cfg.warm}

            ${lib.optionalString (cfg.stampPath != null) ''
              mkdir -p "$(dirname "${cfg.stampPath}")"
              date -u +%s > "${cfg.stampPath}"
            ''}
          ''}

          ${lib.optionalString (cfg.notify != null) ''
            meta=$(mktemp)
            new=$(mktemp)
            old="$STATE_DIRECTORY/inputs"
            nix flake metadata "${flake}" --refresh --json 2>/dev/null > "$meta" || true
            jq -r '.locks as $l | $l.nodes.root.inputs | to_entries[]
                   | select(.value | type == "string")
                   | ($l.nodes[.value].locked.rev // empty) as $rev
                   | "\(.key) \($rev[0:7])"' "$meta" 2>/dev/null \
              | sort > "$new" || true

            packages=""
            nixpkgs_changed=0
            if [ -f "$old" ] && [ -s "$new" ]; then
              changed=$(grep -vxFf "$old" "$new" | awk '{ print $1 }' || true)
              packages=$(printf '%s\n' "$changed" | grep -vx nixpkgs | paste -sd, - | sed 's/,/, /g' || true)
              if printf '%s\n' "$changed" | grep -qx nixpkgs; then nixpkgs_changed=1; fi
            fi
            if [ -s "$new" ]; then cp "$new" "$old"; fi
            rm -f "$new"

            channel=""
            if [ "$nixpkgs_changed" = 1 ]; then
              ts=$(jq -r '.locks as $l | ($l.nodes[$l.nodes.root.inputs.nixpkgs].locked.lastModified // empty)' "$meta" 2>/dev/null || true)
              if [ -n "$ts" ]; then channel="nixpkgs $(date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || true)"; fi
            fi
            rm -f "$meta"

            warnings=$(sort -u "$warns" | head -n 15)

            if [ -n "$packages" ] || [ -s "$report" ] || [ -n "$warnings" ]; then
              if [ "$rc" -eq 0 ]; then prio="default"; else prio="high"; fi
              {
                if [ -s "$report" ]; then printf 'FAULTS\n'; sed 's/^/  /' "$report"; fi
                if [ -n "$channel" ]; then printf 'CHANNEL\n  %s\n\n' "$channel"; fi
                if [ -n "$packages" ]; then printf 'PACKAGES\n  %s\n\n' "$packages"; fi
                if [ -n "$warnings" ]; then printf 'WARNINGS\n'; printf '%s\n' "$warnings" | sed 's/^/  /'; fi
              } | curl -fsS \
                -H "Priority: $prio" \
                --data-binary @- "${cfg.notify}" || true
            fi
          ''}

          exit "$rc"
        '';
      };
    in
    {
      options.deploy = {
        cache = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Local Attic cache that built closures are pushed into.";
        };
        warm = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Hosts whose closures are built and cached for self-upgrade pull (no remote activation).";
        };
        targets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Hosts this machine builds, pushes, and activates over Tailscale SSH (MagicDNS names).";
        };
        stampPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional path overwritten with the current Unix timestamp after a successful cache warm-up.";
        };
        notify = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional ntfy topic URL the daily run digest (upgraded inputs, faults, warnings) is POSTed to.";
        };
      };

      config = lib.mkIf (cfg.warm != [ ] || cfg.targets != [ ]) {
        systemd.services.deploy = {
          description = "Build, cache, and deploy host closures";
          after = [
            "network-online.target"
            "tailscaled.service"
            "atticd.service"
            "attic-cache.service"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            Environment = "HOME=/root";
            StateDirectory = "deploy";
            ExecStart = lib.getExe pipeline;
          };
        };
        systemd.timers.deploy = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "02:00";
            Persistent = true;
          };
        };
      };
    };
}
