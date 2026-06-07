{ ... }:
{
  flake.overlays.pi = final: _prev: {
    pi-acp = final.writeShellApplication {
      name = "pi-acp";
      runtimeInputs = [
        final.bun
        final.pi-coding-agent
      ];
      text = ''
        exec bun x pi-acp "$@"
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
