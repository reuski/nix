{ lib, ... }:
let
  label = "com.vanta.metalauncher";
  plist = "/Library/LaunchDaemons/${label}.plist";
  bin = "/usr/local/vanta/metalauncher";
in
{
  system.activationScripts.vanta.text = ''
    if [ -f ${lib.escapeShellArg plist} ] && ! /usr/bin/pgrep -f ${lib.escapeShellArg bin} >/dev/null 2>&1; then
      /bin/launchctl bootstrap system ${lib.escapeShellArg plist} >/dev/null 2>&1 || true
      /bin/launchctl kickstart system/${label} >/dev/null 2>&1 || true
    fi
  '';
}
