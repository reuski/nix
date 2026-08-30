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
      subagentProfile = model: thinking: fallbackModels: {
        inherit model thinking fallbackModels;
      };
      piPackages = [
        {
          source = "npm:pi-mcp-adapter";
          skills = [ ];
        }
        "npm:pi-web-access"
        "npm:pi-subagents"
        {
          source = "npm:context-mode";
          skills = [ "+skills/context-mode/SKILL.md" ];
        }
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
          # Rules

          - Inspect the target and nearby ownership before editing.
          - Prefer existing patterns and upstream options; use precise names, narrow ownership, and only used code.
          - Comment only for algorithmic rationale.
          - Batch independent reads, patch atomically, and delete superseded code.
          - Use `read`, `rg`, `rg --files`, and `edit`; keep commands non-interactive, scoped, quoted, and output-bounded.
          - Use repository tooling or its dev shell; never install temporary tools globally.
          - Verify every edit; report changed files, commands, and results.
          - Before destructive work, ask with `ACTION / COMMAND / REASON`. This includes force push, `git reset --hard`, `rm -rf`, overwriting `.env` or lockfiles, package removal, `sudo`, and service stop.
          - Edit tracked files without asking; commit only when asked; never expose secrets.
          - Read `PI_PROVIDER`, `PI_MODEL`, and `PI_REASONING_LEVEL` when runtime identity matters.
          - Answer directly and concisely in plain ASCII; state blockers only with evidence.
        '';

        home.file.".pi/agent/themes/gruvbox.json".source =
          json.generate "pi-gruvbox-theme.json" gruvboxTheme;

        home.file.".pi/agent/extensions/subagent/config.json".source =
          json.generate "pi-subagent-config.json"
            {
              toolDescriptionMode = "compact";
              forkContext = {
                mode = "pruned";
                model = "openai-codex/gpt-5.6-luna:low";
              };
              globalConcurrencyLimit = 4;
              maxSubagentSpawnsPerRun = 8;
            };

        home.file.".pi/agent/web-search.json".source = json.generate "pi-web-search.json" {
          workflow = "none";
          maxInlineContentChars = 12000;
          searxngBaseUrl = "https://ukko.tail2fc4c2.ts.net/api";
          searchRouting = {
            providers = [
              "searxng"
              "openai"
              "exa"
            ];
            useCurrentModel = true;
            fallbackOn = [
              "unsupported"
              "transient"
              "quota"
              "network"
              "invalid-response"
            ];
          };
        };

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
          branchSummary.skipPrompt = true;
          enabledModels = [
            "openai-codex/gpt-5.6-luna"
            "openai-codex/gpt-5.6-sol"
            "zai/glm-5.3-flash"
            "deepseek/deepseek-v4-pro"
          ]
          ++ lib.optional localModel.enable "local/local";
          modelThinkingLevels = {
            "openai-codex/gpt-5.6-sol" = "high";
            "openai-codex/gpt-5.6-luna" = "medium";
            "zai/glm-5.3-flash" = "medium";
            "deepseek/deepseek-v4-pro" = "high";
          };
          subagents.agentOverrides = {
            scout = subagentProfile "zai/glm-5.3-flash" "low" [
              "openai-codex/gpt-5.6-luna:low"
            ];
            researcher = subagentProfile "openai-codex/gpt-5.6-luna" "medium" [
              "zai/glm-5.3-flash:low"
            ];
            delegate = subagentProfile "zai/glm-5.3-flash" "low" [
              "openai-codex/gpt-5.6-luna:low"
            ];
            worker = subagentProfile "openai-codex/gpt-5.6-luna" "medium" [
              "deepseek/deepseek-v4-pro:high"
            ];
            reviewer = subagentProfile "openai-codex/gpt-5.6-sol" "high" [
              "deepseek/deepseek-v4-pro:high"
            ];
            oracle = subagentProfile "openai-codex/gpt-5.6-sol" "high" [
              "deepseek/deepseek-v4-pro:high"
            ];
          };
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.6-luna";
        };

        home.file.".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
          settings.scriptMode = false;
          mcpServers.nixos.command = lib.getExe' pkgs.mcp-nixos "mcp-nixos";
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
