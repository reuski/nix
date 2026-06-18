{
  config,
  pkgs,
  ...
}:
{
  services.pipewire = {
    jack.enable = true;
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [
          44100
          48000
          96000
        ];
        "default.clock.quantum" = 64;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 2048;
      };
    };
  };

  users.users.${config.profile.username}.extraGroups = [
    "audio"
    "render"
    "input"
  ];

  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = 99;
    }
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "nofile";
      type = "-";
      value = 99999;
    }
  ];

  home-manager.users.${config.profile.username}.home.packages = with pkgs; [
    reaper
    reaper-sws-extension
    reaper-reapack-extension
    yabridge
    yabridgectl
    wineWow64Packages.staging
  ];
}
