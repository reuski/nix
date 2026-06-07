{ ... }:
{
  flake.modules.homeManager.pi =
    { pkgs, ... }:
    let
      json = pkgs.formats.json { };
    in
    {
      home.packages = with pkgs; [
        pi-coding-agent
        pi-acp
      ];

      home.file.".pi/agent/AGENTS.md".text = ''
        # Operational Directives

        ## 1. Interaction Protocol

        - **Zero Latency:** Eliminate conversational filler, pleasantries, and meta-commentary.
        - **Token Efficiency:** Batch tool executions. Minimize output verbosity without losing clarity.
        - **Context Awareness:** Dynamically adapt to the detected environment, languages, and frameworks.

        ## 2. Engineering Standards

        - **Modern Best Practices:** Utilize bleeding-edge, stable features of the target language.
        - **Code Hygiene:**
          - **Self-Documenting:** Naming must be precise. Comments are prohibited except for complex algorithmic rationale.
          - **Lean Implementation:** Strict adherence to YAGNI and KISS. No over-engineering.
          - **Purity:** Prefer functional patterns (immutability, side-effect isolation) where applicable.
        - **Architecture:** Maintain strict separation of concerns. Ensure modularity and testability.

        ## 3. Execution Lifecycle

        - **Discovery:** Proactively map the codebase and read configuration files before formulating a plan.
        - **Implementation:** Perform atomic, idempotent changes.
        - **Verification:** Shift-left. Validate syntax and basic functionality immediately post-generation.
      '';

      home.file.".pi/agent/settings.json".source = json.generate "pi-settings.json" {
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
          "openai-codex/gpt-5.5"
          "moonshot/kimi-k2.6"
          "zai/glm-5.1"
          "deepseek/deepseek-v4-pro"
          "local/local"
        ];
        markdown.codeBlockIndent = "  ";
        defaultProvider = "local";
        defaultModel = "local";
      };

      home.file.".pi/agent/models.json".source = json.generate "pi-models.json" {
        providers = {
          moonshot = {
            baseUrl = "https://api.moonshot.ai/v1";
            api = "openai-completions";
            apiKey = "MOONSHOT_API_KEY";
            compat = {
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
            };
            models = [
              {
                id = "kimi-k2.6";
                name = "Kimi K2.6";
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 262144;
                maxTokens = 65536;
                cost = {
                  input = 0.6;
                  output = 2.5;
                  cacheRead = 0.15;
                  cacheWrite = 0;
                };
              }
            ];
          };

          deepseek = {
            baseUrl = "https://api.deepseek.com/v1";
            api = "openai-completions";
            apiKey = "DEEPSEEK_API_KEY";
            compat = {
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
            };
            models = [
              {
                id = "deepseek-v4-pro";
                name = "DeepSeek V4 Pro";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 262144;
                maxTokens = 65536;
                cost = {
                  input = 0.55;
                  output = 2.19;
                  cacheRead = 0.14;
                  cacheWrite = 0;
                };
              }
            ];
          };

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
