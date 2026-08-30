{ ... }:
{
  flake.overlays.pi = final: _prev: {
    pi-coding-agent = final.writeShellApplication {
      name = "pi";
      runtimeInputs = [
        final.bun
        final.nodejs
        final.ripgrep
        final.fd
      ];
      text = ''
        export PI_CACHE_RETENTION="''${PI_CACHE_RETENTION:-long}"
        export PI_SKIP_VERSION_CHECK="''${PI_SKIP_VERSION_CHECK:-1}"
        export PI_SUBAGENT_PI_BINARY="''${PI_SUBAGENT_PI_BINARY:-$0}"
        exec ${final.lib.getExe final.bun} x @earendil-works/pi-coding-agent@latest "$@"
      '';
      meta = {
        description = "Pi Coding Agent";
        homepage = "https://pi.dev/";
        license = final.lib.licenses.mit;
        mainProgram = "pi";
        platforms = final.lib.platforms.unix;
      };
    };

    pi-acp = final.writeShellApplication {
      name = "pi-acp";
      runtimeInputs = [
        final.bun
        final.nodejs
        final.pi-coding-agent
      ];
      text = ''
        exec ${final.lib.getExe final.bun} x pi-acp@latest "$@"
      '';
      meta = {
        description = "ACP adapter wrapper for Pi Coding Agent";
        homepage = "https://github.com/svkozak/pi-acp";
        license = final.lib.licenses.mit;
        mainProgram = "pi-acp";
        platforms = final.lib.platforms.unix;
      };
    };
  };
}
