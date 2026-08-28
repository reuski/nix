{ ... }:
{
  flake.modules.homeManager.pi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      localModel = config.pi.localModel;
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
      options.pi.localModel = {
        enable = lib.mkEnableOption "local llama.cpp model in Pi";
        contextWindow = lib.mkOption {
          type = lib.types.ints.positive;
          default = 65536;
        };
        vision = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };

      config = {
        home.packages = with pkgs; [
          pi-coding-agent
          pi-acp
          mcp-nixos
        ];

        home.file.".pi/agent/AGENTS.md".text = ''
          # Operating Rules

          ## Work

          - Read targets and nearby ownership before editing.
          - Prefer precise names, narrow ownership, and upstream options.
          - Add only used code and comments that explain algorithmic rationale.
          - Batch independent tool calls; patch atomically; remove superseded code.
          - Verify each edit and report changed files, commands, and results.

          ## Tools

          - Use `read` for files, `rg` and `rg --files` for search, and `edit` for exact changes.
          - Keep shell commands non-interactive, quoted, scoped, and output-bounded.
          - Prefer repository commands and its dev shell. For a missing tool, use `nix develop -c`, then `nix shell nixpkgs#<package> -c <program>`. Use `nix run nixpkgs#<package> --` for a package's main program.
          - Never use `nix-env` or global installs for temporary tools.
          - Read `PI_PROVIDER`, `PI_MODEL`, and `PI_REASONING_LEVEL` instead of guessing runtime state.

          ## Safety

          - Before a destructive action, ask with `ACTION / COMMAND / REASON`.
          - Destructive actions include force push, `git reset --hard`, `rm -rf`, overwriting `.env` or lockfiles, package removal, `sudo`, and service stop.
          - Edit tracked files without asking; commit only when asked; never expose secrets.

          ## Output

          - Answer directly and concisely in plain ASCII.
          - State blockers only with evidence.
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
          defaultThinkingLevel = "medium";
          compaction = {
            enabled = true;
            reserveTokens = 16384;
            keepRecentTokens = 20000;
          };
          branchSummary = {
            reserveTokens = 16384;
            skipPrompt = true;
          };
          steeringMode = "one-at-a-time";
          followUpMode = "one-at-a-time";
          transport = "auto";
          enabledModels = [
            "zai/glm-5.2"
            "moonshotai/kimi-k2.6"
            "deepseek/deepseek-v4-pro"
          ]
          ++ lib.optional localModel.enable "local/local";
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
        };

        home.file.".pi/agent/models.json".source = json.generate "pi-models.json" {
          providers = lib.optionalAttrs localModel.enable {
            local = {
              baseUrl = "http://127.0.0.1:8080/v1";
              api = "openai-completions";
              apiKey = "llama";
              compat = {
                supportsStore = false;
                supportsDeveloperRole = false;
                supportsReasoningEffort = false;
                supportsUsageInStreaming = true;
                supportsStrictMode = false;
                thinkingFormat = "chat-template";
                chatTemplateKwargs = {
                  enable_thinking."$var" = "thinking.enabled";
                  preserve_thinking = true;
                  reasoning_effort = {
                    "$var" = "thinking.effort";
                    omitWhenOff = true;
                  };
                };
                maxTokensField = "max_tokens";
              };
              models = [
                {
                  id = "local";
                  name = "llama.cpp";
                  reasoning = true;
                  thinkingLevelMap = {
                    minimal = "low";
                    low = "low";
                    medium = "medium";
                    high = "xhigh";
                    xhigh = "xhigh";
                    max = "xhigh";
                  };
                  input = [ "text" ] ++ lib.optional localModel.vision "image";
                  contextWindow = localModel.contextWindow;
                  maxTokens = 16384;
                  samplingParams = {
                    temperature = 1.0;
                    top_k = 20;
                    top_p = 0.95;
                    min_p = 0.0;
                  };
                }
              ];
            };
          };
        };
      };
    };
}
