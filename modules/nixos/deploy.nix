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
          pkgs.jq
          pkgs.coreutils
        ]
        ++ lib.optionals (cfg.notify != null) [
          pkgs.curl
          pkgs.gawk
        ]
        ++ lib.optionals (cfg.targets != [ ]) [
          pkgs.nixos-rebuild
          pkgs.openssh
        ]
        ++ lib.optionals (cfg.warm != [ ]) [ pkgs.attic-client ];
        text = ''
          rc=0
          score=$(mktemp)
          detail=$(mktemp)
          warns=$(mktemp)
          meta=$(mktemp)
          new=$(mktemp)
          deployment_flake=${flake}
          if ! revision=$(nix flake metadata "$deployment_flake" --refresh --json | jq -er '.locked.rev'); then
            echo "failed to resolve deployment flake revision" >&2
            exit 1
          fi
          deployment_flake="github:reuski/nix/$revision"

          ${lib.optionalString (cfg.notify != null) ''
            old="$STATE_DIRECTORY/inputs"
            nix flake metadata "$deployment_flake" --json 2>/dev/null > "$meta" || true
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

            channel=""
            if [ "$nixpkgs_changed" = 1 ]; then
              ts=$(jq -r '.locks as $l | ($l.nodes[$l.nodes.root.inputs.nixpkgs].locked.lastModified // empty)' "$meta" 2>/dev/null || true)
              if [ -n "$ts" ]; then channel="nixpkgs $(date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || true)"; fi
            fi

            # shellcheck disable=SC2329
            notify() {
              warnings=$(sort -u "$warns" | head -n 10)
              total=$(wc -l < "$score" | tr -d ' ')
              ok=$(grep -c ' OK$' "$score" || true)
              status=$( [ "$rc" -eq 0 ] && printf OK || printf FAIL )
              headline="DEPLOY $ok/$total $status"
              prio=$( [ "$rc" -eq 0 ] && printf default || printf high )

              {
                printf '%s\n\n' "$headline"
                cat "$score"
                [ -s "$detail" ] && { printf '\n'; cat "$detail"; }
                [ -n "$channel" ] && printf '\nCHANNEL %s\n' "$channel"
                [ -n "$packages" ] && printf '\nINPUTS %s\n' "$packages"
                [ -n "$warnings" ] && printf '\nWARN\n%s\n' "$warnings"
              } | curl -fsS \
                  -H "Priority: $prio" \
                  --data-binary @- "${cfg.notify}" || true
            }
          ''}

          # shellcheck disable=SC2329
          summarize() {
            ${lib.optionalString (cfg.notify != null) "notify || true"}
            rm -f "$score" "$detail" "$warns" "$meta" "$new"
          }
          trap summarize EXIT
          trap 'rc=1; exit 143' TERM
          trap 'rc=1; exit 130' INT

          collect() { grep -iE 'warning:' "$1" >> "$warns" || true; }
          mark() { printf '%s %s %s\n' "$1" "$2" "$3" >> "$score"; }

          ${lib.optionalString (cfg.targets != [ ]) ''
            export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes${
              lib.optionalString (cfg.sshKey != null) " -i ${cfg.sshKey}"
            }"

            activate() {
              local target=$1 dest=$2 attempt
              for attempt in 1 2 3; do
                nixos-rebuild switch --flake "$deployment_flake#$target" \
                  --target-host "$dest" --fallback --option tarball-ttl 0 \
                  --max-jobs 1 --cores ${toString cfg.cores} && return 0
                [ "$attempt" -lt 3 ] && sleep $(( attempt * 30 ))
              done
              return 1
            }

            reboot_if_stale() {
              ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes${
                lib.optionalString (cfg.sshKey != null) " -i ${cfg.sshKey}"
              } "$1" '
                booted=$(readlink /run/booted-system/{kernel,initrd,kernel-modules})
                built=$(readlink /run/current-system/{kernel,initrd,kernel-modules})
                [ "$booted" = "$built" ] || systemctl reboot'
            }

            preflight() {
              local target=$1 attempt
              for attempt in 1 2 3; do
                if nix build "$deployment_flake#nixosConfigurations.$target.config.system.build.toplevel" \
                    --fallback --option tarball-ttl 0 --no-link --print-out-paths \
                    --max-jobs 1 --cores ${toString cfg.cores} >/dev/null; then
                  return 0
                fi
                [ "$attempt" -lt 3 ] && sleep $(( attempt * 30 ))
              done
              return 1
            }

            preflight_failed=0
            ${lib.concatMapStringsSep "\n" (h: ''
              if ! preflight ${h}; then
                rc=1
                preflight_failed=1
                mark PREFLIGHT ${h} FAIL
                printf '%s\n' ${h} >> "$detail"
              else
                mark PREFLIGHT ${h} OK
              fi
            '') cfg.targets}
            if [ "$preflight_failed" = 1 ]; then exit "$rc"; fi

            ${lib.concatMapStringsSep "\n" (
              h:
              let
                dest = cfg.sshHosts.${h} or "root@${h}";
              in
              ''
                log=$(mktemp)
                if activate ${h} "${dest}" > "$log" 2>&1; then
                  mark ACT ${h} OK
                  reboot_if_stale "${dest}" || true
                else
                  rc=1
                  mark ACT ${h} FAIL
                  { printf '%s\n' ${h}; grep -iE 'error|fatal|fail|exception' "$log" | tail -n 3; } >> "$detail"
                fi
                collect "$log"
                rm -f "$log"
              ''
            ) cfg.targets}
          ''}

          ${lib.optionalString (cfg.warm != [ ]) ''
            warm() {
              local out attempt
              for attempt in 1 2 3; do
                if out=$(nix build "$deployment_flake#nixosConfigurations.$1.config.system.build.toplevel" \
                    --fallback --option tarball-ttl 0 --no-link --print-out-paths \
                    --max-jobs 1 --cores ${toString cfg.cores} 2>> "$2"); then
                  attic push "local:${cfg.cache}" "$out" >> "$2" 2>&1
                  return 0
                fi
                [ "$attempt" -lt 3 ] && sleep $(( attempt * 30 ))
              done
              return 1
            }

            # shellcheck disable=SC2154
            attic login local http://127.0.0.1:8090 "$(cat "$CREDENTIALS_DIRECTORY/attic-token")"

            primed=1
            ${lib.concatMapStringsSep "\n" (h: ''
              log=$(mktemp)
              if warm ${h} "$log"; then
                mark WARM ${h} OK
              else
                rc=1
                primed=0
                mark WARM ${h} FAIL
                { printf '%s\n' ${h}; grep -iE 'error|fatal|fail|exception' "$log" | tail -n 3; } >> "$detail"
              fi
              collect "$log"
              rm -f "$log"
            '') cfg.warm}

            ${lib.optionalString (cfg.stampPath != null) ''
              if [ "$primed" = 1 ]; then
                mkdir -p "$(dirname "${cfg.stampPath}")"
                date -u +%s > "${cfg.stampPath}"
              fi
            ''}
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
          description = "Hosts this machine builds, pushes, and activates over SSH.";
        };
        sshKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional path to an SSH private key used to authenticate to targets.";
        };
        sshHosts = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Optional per-target SSH destination (user@host), overriding root@<target>.";
        };
        stampPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional path overwritten with the current Unix timestamp after a successful cache warm-up.";
        };
        notify = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ntfy topic URL a per-run digest (scoreboard, faults, input delta, warnings) is always POSTed to.";
        };
        cores = lib.mkOption {
          type = lib.types.ints.positive;
          default = 4;
          description = "CPU cores allotted to build steps; caps nightly thermal load and concurrent substituter load.";
        };
      };

      config = lib.mkIf (cfg.warm != [ ] || cfg.targets != [ ]) {
        assertions = [
          {
            assertion = cfg.warm == [ ] || cfg.cache != "";
            message = "deploy.cache must be set when deploy.warm is enabled";
          }
        ];

        systemd.services.nixos-upgrade = lib.mkIf config.system.autoUpgrade.enable {
          after = [ "deploy.service" ];
        };

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
            TimeoutStartSec = "4h";
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
