{ ... }:
{
  flake.modules.nixos.alerts =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.alerts;

      checker = pkgs.writeShellApplication {
        name = "hardware-alerts";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.curl
        ];
        text = ''
          host="${config.networking.hostName}"

          post() { curl -fsS -H "Priority: $1" --data-raw "$2" "${cfg.ntfy}" || true; }

          evaluate() {
            local key=$1 value=$2 warn=$3 crit=$4 unit=$5 label=$6
            local now prio f prev=""
            case "$value" in "" | *[!0-9]*) return 0 ;; esac
            if [ "$value" -ge "$crit" ]; then
              now=CRITICAL
              prio=high
            elif [ "$value" -ge "$warn" ]; then
              now=WARN
              prio=default
            else
              now=OK
            fi
            f="$STATE_DIRECTORY/$key"
            if [ -f "$f" ]; then prev=$(cat "$f"); fi
            if [ "$now" = "$prev" ]; then return 0; fi
            printf '%s' "$now" > "$f"
            if [ "$now" = OK ]; then
              if [ "$prev" != WARN ] && [ "$prev" != CRITICAL ]; then return 0; fi
              post min "$(printf '%s // %s %s%s CLEARED' "$host" "$label" "$value" "$unit")"
            else
              post "$prio" "$(printf '%s // %s %s%s %s' "$host" "$label" "$value" "$unit" "$now")"
            fi
          }

          while read -r mount pct; do
            [ -n "$mount" ] || continue
            evaluate "disk$(printf '%s' "$mount" | tr / _)" "$pct" 80 90 % "DISK $mount"
          done < <(df -P -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay -x ramfs -x fuse.portal 2>/dev/null \
            | awk 'NR > 1 { gsub(/%/, "", $5); print $6, $5 }')

          read -r mtotal mavail < <(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } END { print t, a }' /proc/meminfo) || true
          if [ -n "$mtotal" ] && [ -n "$mavail" ] && [ "$mtotal" -gt 0 ]; then
            evaluate memory "$(((mtotal - mavail) * 100 / mtotal))" 80 90 % MEMORY
          fi

          temp=0
          for zone in /sys/class/thermal/thermal_zone*/temp; do
            [ -r "$zone" ] || continue
            read -r reading < "$zone" || continue
            case "$reading" in "" | *[!0-9]*) continue ;; esac
            if [ "$reading" -gt "$temp" ]; then temp=$reading; fi
          done
          if [ "$temp" -gt 0 ]; then
            tc=$((temp / 1000))
            if [ "$tc" -ge 20 ] && [ "$tc" -le 120 ]; then
              evaluate temperature "$tc" 75 85 C TEMP
            fi
          fi
        '';
      };
    in
    {
      options.alerts = {
        ntfy = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ntfy topic URL hardware alerts are POSTed to. Edge-triggered on threshold crossings + recovery; thresholds match heimdash defaults (disk 80/90, memory 80/90, temperature 75/85 °C). CPU is intentionally not alerted (transient).";
        };
        interval = lib.mkOption {
          type = lib.types.str;
          default = "15min";
          description = "systemd OnUnitActiveSec cadence for the hardware alert check.";
        };
      };

      config = lib.mkIf (cfg.ntfy != null) {
        systemd.services.hardware-alerts = {
          description = "Hardware threshold alerts to ntfy";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "hardware-alerts";
            ExecStart = lib.getExe checker;
          };
        };
        systemd.timers.hardware-alerts = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
        };
      };
    };
}
