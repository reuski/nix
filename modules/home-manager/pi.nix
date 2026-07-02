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
        "npm:pi-intercom"
        "npm:context-mode"
      ];
      gruvboxTheme = {
        "$schema" =
          "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
        name = "gruvbox";
        vars = {
          bg = "#282828";
          fg = "#ebdbb2";
          accent = "#fabd2f";
          accent2 = "#83a598";
          red = "#fb4934";
          green = "#b8bb26";
          yellow = "#fabd2f";
          orange = "#fe8019";
          purple = "#d3869b";
          gray = "#a89984";
          dimGray = "#928374";
          surface = "#32302f";
          surface2 = "#3c3836";
          surface3 = "#504945";
          toolPendingBg = "#2d2a28";
          toolSuccessBg = "#303522";
          toolErrorBg = "#3a2722";
          customMsgBg = "#342d32";
        };
        colors = {
          accent = "accent";
          border = "accent";
          borderAccent = "accent2";
          borderMuted = "surface3";
          success = "green";
          error = "red";
          warning = "yellow";
          muted = "gray";
          dim = "dimGray";
          text = "fg";
          thinkingText = "gray";
          selectedBg = "surface3";
          userMessageBg = "surface";
          userMessageText = "fg";
          customMessageBg = "customMsgBg";
          customMessageText = "fg";
          customMessageLabel = "accent2";
          toolPendingBg = "toolPendingBg";
          toolSuccessBg = "toolSuccessBg";
          toolErrorBg = "toolErrorBg";
          toolTitle = "accent2";
          toolOutput = "gray";
          mdHeading = "yellow";
          mdLink = "accent2";
          mdLinkUrl = "dimGray";
          mdCode = "orange";
          mdCodeBlock = "green";
          mdCodeBlockBorder = "surface3";
          mdQuote = "gray";
          mdQuoteBorder = "purple";
          mdHr = "surface3";
          mdListBullet = "accent";
          toolDiffAdded = "green";
          toolDiffRemoved = "red";
          toolDiffContext = "gray";
          syntaxComment = "dimGray";
          syntaxKeyword = "purple";
          syntaxFunction = "accent2";
          syntaxVariable = "fg";
          syntaxString = "green";
          syntaxNumber = "orange";
          syntaxType = "yellow";
          syntaxOperator = "accent";
          syntaxPunctuation = "gray";
          thinkingOff = "surface3";
          thinkingMinimal = "dimGray";
          thinkingLow = "accent";
          thinkingMedium = "accent2";
          thinkingHigh = "purple";
          thinkingXhigh = "red";
          bashMode = "green";
        };
        export = {
          pageBg = "#282828";
          cardBg = "#32302f";
          infoBg = "#3c3836";
        };
      };
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

        ## Safety

        - Gate destructive actions: force push, `git reset --hard`, `rm -rf`, overwriting `.env`/lockfiles, package removal, `sudo`, service stop.
        - Confirm with `ACTION / COMMAND / REASON` before executing.
        - Do not over-ask for recoverable git-tracked edits.
      '';

      home.file.".pi/agent/themes/gruvbox.json".source =
        json.generate "pi-gruvbox-theme.json" gruvboxTheme;

      home.file.".pi/agent/settings.json".source = json.generate "pi-settings.json" {
        packages = piPackages;
        theme = "gruvbox";
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
        mcpServers.grep = {
          url = "https://mcp.grep.app";
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
