{ ... }:
{
  flake.modules.homeManager.pi =
    { pkgs, lib, ... }:
    let
      json = pkgs.formats.json { };
      piPackages = [
        "npm:pi-mcp-adapter"
        "npm:pi-web-access"
        "npm:pi-subagents"
        "npm:context-mode"
      ];
    in
    {
      home.packages = with pkgs; [
        pi-coding-agent
        pi-acp
        mcp-nixos
      ];

      home.file.".pi/agent/AGENTS.md".text = ''
        # Operational Directives

        ## Protocol

        - No filler.
        - Batch tool calls.
        - Prefer `rg` and `rg --files`.
        - Read before planning.
        - State blockers only with evidence.

        ## Engineering

        - Bleeding-edge features.
        - Precise and concise names.
        - No comments except algorithmic rationale.
        - YAGNI.
        - KISS.
        - Functional shape where it clarifies.
        - Strict ownership boundaries.

        ## Lifecycle

        - Discover.
        - Patch atomically.
        - Delete dead config.
        - Verify immediately.
        - Report changed files and validation.
      '';

      home.file.".pi/agent/settings.json".source = json.generate "pi-settings.json" {
        packages = piPackages;
        terminal.showImages = false;
        hideThinkingBlock = true;
        quietStartup = true;
        collapseChangelog = true;
        enableInstallTelemetry = false;
        treeFilterMode = "user-only";
        defaultThinkingLevel = "high";
        thinkingBudgets = {
          minimal = 1024;
          low = 4096;
          medium = 16384;
          high = 32768;
          xhigh = 65536;
        };
        compaction = {
          enabled = true;
          reserveTokens = 32768;
          keepRecentTokens = 48000;
        };
        branchSummary = {
          reserveTokens = 16384;
          skipPrompt = true;
        };
        retry = {
          enabled = true;
          maxRetries = 5;
          baseDelayMs = 2000;
          provider.maxRetryDelayMs = 60000;
        };
        steeringMode = "one-at-a-time";
        followUpMode = "one-at-a-time";
        transport = "auto";
        enabledModels = [
          "zai/glm-5.2"
          "moonshotai/kimi-k2.6"
          "deepseek/deepseek-v4-pro"
          "local/local"
        ];
        markdown.codeBlockIndent = "  ";
        defaultProvider = "zai";
        defaultModel = "glm-5.2";
      };

      home.file.".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
        mcpServers.nixos = {
          command = lib.getExe' pkgs.mcp-nixos "mcp-nixos";
          lifecycle = "lazy";
          idleTimeout = 10;
        };
        mcpServers."context-mode" = {
          command = lib.getExe' pkgs.bun "bunx";
          args = [ "context-mode" ];
        };
      };

      home.file.".pi/agent/models.json".source = json.generate "pi-models.json" {
        providers = {
          local = {
            baseUrl = "http://localhost:8080";
            api = "openai-completions";
            apiKey = "llama";
            compat = {
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
              supportsUsageInStreaming = true;
              maxTokensField = "max_tokens";
            };
            models = [
              {
                id = "local";
                name = "llama-server";
                input = [ "text" ];
                contextWindow = 65536;
                maxTokens = 16384;
              }
            ];
          };
        };
      };
    };
}
