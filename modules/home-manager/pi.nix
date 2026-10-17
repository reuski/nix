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
      piPackages = [ "npm:pi-web-access" ];
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

        home.file.".pi/agent/themes/gruvbox.json".source = ./pi/gruvbox.json;

        home.file.".pi/agent/AGENTS.md".source = ./pi/instructions.md;

        home.file.".pi/agent/skills/delegate/SKILL.md".source = ./pi/delegate/SKILL.md;

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
          defaultTools = [ "+codemode" ];
          theme = "gruvbox";
          terminal.showImages = true;
          hideThinkingBlock = true;
          quietStartup = true;
          collapseChangelog = true;
          enableInstallTelemetry = false;
          treeFilterMode = "user-only";
          defaultThinkingLevel = "medium";
          branchSummary.skipPrompt = true;
          enabledModels = [
            "openai-codex/gpt-6-luna"
            "openai-codex/gpt-6.1-sol"
            "openai-codex/gpt-6-astra"
            "zai/glm-5.3-flash"
            "deepseek/deepseek-flash"
          ]
          ++ lib.optional localModel.enable "local/local";
          modelThinkingLevels = {
            "openai-codex/gpt-6-luna" = "high";
            "openai-codex/gpt-6.1-sol" = "medium";
            "openai-codex/gpt-6-astra" = "high";
            "zai/glm-5.3-flash" = "high";
            "deepseek/deepseek-flash" = "high";
          };
          defaultProvider = "openai-codex";
          defaultModel = "gpt-6.1-sol";
        };

        home.file.".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
          mcpServers.nixos = {
            command = lib.getExe' pkgs.mcp-nixos "mcp-nixos";
            description = "Search NixOS, Home Manager, and nix-darwin packages and configuration options";
            exposure = "codemode";
          };
        };

        home.file.".pi/agent/models.json".source = json.generate "pi-models.json" {
          providers = {
            zai.baseUrl = "https://api.z.ai/api/paas/v4";
          }
          // lib.optionalAttrs localModel.enable {
            local = {
              baseUrl = "http://127.0.0.1:9931/v1";
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
                }
              ];
            };
          };
        };
      };
    };
}
