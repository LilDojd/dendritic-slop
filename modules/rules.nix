{ config, ... }:
let
  piModule = config.flake.modules.homeManager.pi;
  targetModule =
    { config, lib, ... }:
    {
      options.dendriticSlop.targets.rules.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Pi rules for declarative global tooling and Herdr agent selection.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.rules.enable) {
        dendriticSlop.targets.pi.enable = lib.mkDefault true;
        programs.pi.coding-agent.rules =
          # markdown
          ''
            # Declarative self-management

            Global Pi and LLM tooling is managed by the `dendritic-slop` flake and its consuming host flake.

            Apply these rules to global Pi and LLM tooling changes:

            1. Change `dendritic-slop` for shared resources, or the consuming flake for host selection and secrets. Do not mutate runtime configuration or use `pi install`.
            2. Pin and review external packages, skills, and extensions before enabling them.
            3. Keep credentials and transient state outside the Nix store.
            4. Format changed Nix files and run `nix flake check --no-eval-cache --no-build --all-systems`.

            These global-management rules do not restrict project-local Pi or MCP configuration.

            # Python tool selection

            Respect each repository's existing Python package manager, formatter, linter, and type checker. Prefer project-pinned `uv run` tools, then declaratively packaged tools. Do not use `uvx`, install packages, or migrate project tooling without explicit user approval.

            # Herdr agent selection

            When working in Herdr, only spawn Pi agents unless the user explicitly requests another agent kind.
          '';
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
