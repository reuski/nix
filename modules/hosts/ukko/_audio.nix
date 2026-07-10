{
  config,
  lib,
  ...
}:
{
  services.skaldi.enable = true;
  services.skaldi.settings.opensubsonic = {
    enabled = true;
    library_id = "navidrome";
    base_url = "http://127.0.0.1:4533";
    username = "admin";
    token_file = "/run/credentials/skaldi.service/opensubsonic-token";
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    systemWide = true;
    pulse.enable = true;
    raopOpenFirewall = true;
    extraConfig.pipewire."10-raop-discover"."context.modules" = [
      { name = "libpipewire-module-raop-discover"; }
    ];
  };

  systemd.services.skaldi = {
    environment = {
      PIPEWIRE_RUNTIME_DIR = "/run/pipewire";
      PULSE_SERVER = "unix:/run/pulse/native";
    };
    serviceConfig.SupplementaryGroups = lib.mkForce [
      "pipewire"
    ];
    serviceConfig.LoadCredential = [
      "opensubsonic-token:${config.sops.secrets."navidrome/admin-password".path}"
    ];
  };
}
