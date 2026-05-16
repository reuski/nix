{ ... }:
{
  flake.overlays.pi = final: _prev: {
    pi-coding-agent = final.writeShellApplication {
      name = "pi";
      runtimeInputs = [ final.bun ];
      text = ''
        exec bun x @earendil-works/pi-coding-agent "$@"
      '';
      meta = {
        description = "Pi Coding Agent bunx wrapper";
        homepage = "https://github.com/earendil-works/pi/tree/main/packages/coding-agent";
        license = final.lib.licenses.mit;
        mainProgram = "pi";
        platforms = final.lib.platforms.unix;
      };
    };

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
