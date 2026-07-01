{
  config,
  pkgs,
  ...
}:
{
  services.pipewire = {
    jack.enable = true;
    wireplumber.extraConfig."50-ur22c-default" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_output\.usb-Yamaha_Corporation_Steinberg_UR22C.*"; }
          ];
          actions.update-props."priority.session" = 1500;
        }
        {
          matches = [
            { "node.name" = "~alsa_input\.usb-Yamaha_Corporation_Steinberg_UR22C.*"; }
          ];
          actions.update-props."priority.session" = 1500;
        }
        {
          matches = [
            { "node.name" = "~alsa_input.*[Yy]eti.*"; }
          ];
          actions.update-props."priority.session" = 2000;
        }
      ];
    };
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
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
    mumble
    reaper
    reaper-sws-extension
    reaper-reapack-extension
    yabridge
    yabridgectl
    qpwgraph
    wineWow64Packages.staging
  ];
}
