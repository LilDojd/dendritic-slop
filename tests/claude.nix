{
  config,
  inputs,
  lib,
  mkHome,
  pkgs,
  realizedSkills,
  system,
  ...
}:
let
  # The helper reads the secret at connection time; stdin stands in for a
  # runtime secret file inside the build sandbox.
  homeWithClaude = mkHome {
    dendriticSlop = {
      profiles.core.enable = true;
      targets.claude.enable = true;
      mcps = {
        linear.enable = true;
        context7 = {
          enable = true;
          secrets.apiKeyFile = "/dev/stdin";
        };
      };
    };
  };
  homeWithClaudeOnly = mkHome {
    dendriticSlop = {
      targets = {
        claude.enable = true;
        rules.enable = true;
      };
      skills.bro.enable = true;
      mcps.linear.enable = true;
    };
  };
  claude = homeWithClaude.config.programs.claude-code;
  files = homeWithClaude.config.home.file;
  claudeDir = claude.configDir;
  servers = claude.mcpServers;
in
{
  claude-target =
    assert claude.enable;
    assert claude.package == inputs.llm-agents.packages.${system}.claude-code;
    assert files."${claudeDir}/skills/jujutsu".source == realizedSkills.targets.jujutsu;
    assert !files."${claudeDir}/skills/jujutsu".recursive;
    assert files."${claudeDir}/skills/herdr".source == realizedSkills.targets.herdr;
    assert
      builtins.attrNames homeWithClaude.config.dendriticSlopInternal.skills.selected == builtins.attrNames
        (
          lib.filterAttrs (
            name: _: homeWithClaude.config.dendriticSlop.skills.${name}.enable
          ) config.dendriticSlopInternal.catalog.skills
        );
    assert
      builtins.attrNames servers == [
        "context7"
        "linear"
      ];
    assert
      servers.linear == {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };
    assert !(servers.context7 ? headers);
    assert claude.settings.env.DISABLE_AUTOUPDATER == "1";
    assert builtins.length claude.settings.hooks.SessionStart == 1;
    assert claude.hooks ? "herdr-agent-state.sh";
    assert lib.hasInfix
      "spawn only agents from the following list unless the user explicitly requests another agent kind: pi, claude."
      claude.context;
    assert lib.hasInfix "Declarative self-management"
      homeWithClaudeOnly.config.programs.claude-code.context;
    assert !lib.hasInfix "Herdr agent selection" homeWithClaudeOnly.config.programs.claude-code.context;
    assert lib.hasInfix "requests another agent kind: pi, claude."
      homeWithClaude.config.programs.pi.coding-agent.rules;
    assert lib.hasInfix "# Engineering principles" claude.context;
    assert !homeWithClaudeOnly.config.programs.pi.coding-agent.enable;
    assert !(homeWithClaudeOnly.config.programs.claude-code.settings ? hooks);
    assert builtins.attrNames homeWithClaudeOnly.config.programs.claude-code.mcpServers == [ "linear" ];
    pkgs.runCommand "claude-target-check"
      {
        activation = homeWithClaude.activationPackage;
        claudeOnlyActivation = homeWithClaudeOnly.activationPackage;
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        set -euo pipefail

        headers="$(printf 'runtime-secret' | ${servers.context7.headersHelper})"
        test "$(jq -r .Authorization <<< "$headers")" = 'Bearer runtime-secret'
        ! grep -rF runtime-secret ${servers.context7.headersHelper}

        plugin="$activation/home-files/.claude/skills/claude-code-home-manager"
        jq -e '
          (.mcpServers | keys) == ["context7", "linear"]
          and .mcpServers.context7.type == "http"
          and (.mcpServers.context7.headersHelper | startswith("${builtins.storeDir}/"))
        ' "$plugin/.mcp.json" >/dev/null

        test "$(readlink "$activation/home-files/.claude/skills/jujutsu")" = ${lib.escapeShellArg (toString realizedSkills.targets.jujutsu)}
        test -f "$activation/home-files/.claude/skills/jujutsu/SKILL.md"
        grep -Fq 'HERDR_INTEGRATION_ID=claude' "$activation/home-files/.claude/hooks/herdr-agent-state.sh"
        jq -e '.hooks.SessionStart[0].hooks[0].command | endswith(" session")' \
          "$activation/home-files/.claude/settings.json" >/dev/null
        test -x "$activation/home-path/bin/claude"
        test ! -e "$claudeOnlyActivation/home-path/bin/pi"
        touch "$out"
      '';
}
