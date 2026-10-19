{ ... }:
{
  flake.modules.homeManager.pi =
    {
      lib,
      pkgs,
      ...
    }:
    let
      json = pkgs.formats.json { };
      mcp = builtins.fromJSON (builtins.readFile ./pi/mcp.json);
      webPython = pkgs.python3.withPackages (ps: [ ps.trafilatura ]);
      webSource = lib.fileset.toSource {
        root = ./pi/web;
        fileset = lib.fileset.unions [
          ./pi/web/core.ts
          ./pi/web/extension.ts
          ./pi/web/extract.py
        ];
      };
      webBootstrap = pkgs.replaceVars ./pi/web/bootstrap.ts {
        inherit webSource;
        python = lib.getExe' webPython "python3";
      };
    in
    {
      config = {
        home.packages = with pkgs; [
          pi-coding-agent
          pi-acp
          mcp-nixos
        ];

        home.file.".pi/agent/themes/gruvbox.json".source = ./pi/gruvbox.json;

        home.file.".pi/agent/AGENTS.md".source = ./pi/instructions.md;

        home.file.".pi/agent/skills/delegate/SKILL.md".source = ./pi/delegate/SKILL.md;

        home.file.".pi/agent/skills/review/SKILL.md".source = ./pi/review/SKILL.md;

        home.file.".pi/agent/extensions/web/index.ts".source = webBootstrap;

        home.file.".pi/agent/settings.json".source = ./pi/settings.json;

        home.file.".pi/agent/mcp.json".source = json.generate "pi-mcp.json" (
          lib.recursiveUpdate mcp {
            mcpServers.nixos.command = lib.getExe' pkgs.mcp-nixos "mcp-nixos";
          }
        );

        home.file.".pi/agent/models.json".source = ./pi/models.json;
      };
    };
}
