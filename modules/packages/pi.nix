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
        export PI_SKIP_VERSION_CHECK="''${PI_SKIP_VERSION_CHECK:-1}"
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
  };
}
