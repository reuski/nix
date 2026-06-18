# Per-output display config is runtime state managed by KScreen and not declared
# here: with the iGPU disabled in BIOS the nvidia outputs renumber (DP-3 → DP-1,
# etc.), so a hardcoded kscreen-doctor layout would break on the target. Set the
# three-monitor layout once in System Settings → Display & Monitor on first boot;
# KScreen persists it. Target (from the prior hyprland config):
#   DP-3      2560x1440@180  pos 0,0          scale 1  VRR always, 10-bit, HDR(auto)
#   HDMI-A-4  3840x2160@60   pos 2560,0       scale 1  10-bit, HDR(auto)
#   HDMI-A-5  1920x1200@59.95 pos -1200,-480  scale 1  rotated 90° left, sRGB
#
# Plasma wallpaper is likewise runtime state (plasma-org.kde.plasma.desktop-appletsrc),
# not declarable — the staged images appear in System Settings → Wallpaper; "range"
# is active.
{ config, ... }:
{
  home-manager.users.${config.profile.username}.wallpaper = {
    primary = "range";
    extra = [
      "forage"
      "mountain"
    ];
  };
}
