{ config, ... }:
let
  piModule = config.flake.modules.homeManager.pi;
  targetModule =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop;
      rulesFor =
        {
          harness,
          runtimeMutations,
        }:
        # markdown
        ''
          # Declarative self-management

          Global ${harness} and LLM tooling is managed by the `dendritic-slop` flake and its consuming host flake.

          Apply these rules to global ${harness} and LLM tooling changes:

          1. Change `dendritic-slop` for shared resources, or the consuming flake for host selection and secrets. Do not mutate runtime configuration or use ${runtimeMutations}.
          2. Pin and review external packages, skills, and extensions before enabling them.
          3. Keep credentials and transient state outside the Nix store.
          4. Format changed Nix files and run `nix flake check --no-eval-cache --no-build --all-systems`.

          These global-management rules do not restrict project-local ${harness} or MCP configuration.

          # Python tool selection

          Respect each repository's existing Python package manager, formatter, linter, and type checker. Prefer project-pinned `uv run` tools, then declaratively packaged tools. Do not use `uvx`, install packages, or migrate project tooling without explicit user approval.

          # Herdr agent selection

          When working in Herdr, only spawn ${harness} agents unless the user explicitly requests another agent kind.
        '';
    in
    {
      options.dendriticSlop.targets.rules.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable harness rules for declarative global tooling and Herdr agent selection.";
      };

      config = lib.mkIf (cfg.enable && cfg.targets.rules.enable) {
        programs.pi.coding-agent.rules = lib.mkIf (cfg.targets.pi.enable or false) (rulesFor {
          harness = "Pi";
          runtimeMutations = "`pi install`";
        });
        programs.claude-code.rules.dendritic-slop =
          lib.mkIf (cfg.targets.claude.enable or false)
            (rulesFor {
              harness = "Claude";
              runtimeMutations = "`claude plugin install`, `claude mcp add`, or `/config`";
            });
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.rules.imports = [
    piModule
    targetModule
  ];
}
