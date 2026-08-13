{ config, ... }:
let
  piModule = config.flake.modules.homeManager.pi;
  inherit (config.flake.lib) mkEnableTarget;

  targetModule =
    { config, lib, ... }:
    {
      options.dendriticSlop.targets.rules.enable = mkEnableTarget {
        inherit config lib;
        description = "Enable concise declarative-management rules for Pi.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.rules.enable) {
        dendriticSlop.targets.pi.enable = lib.mkDefault true;
        programs.pi.coding-agent.rules =
          # markdown
          ''
            # Declarative self-management

            Global Pi and LLM tooling is managed by the `dendritic-slop` flake and its consuming host flake.

            When asked to change global Pi or LLM tooling:

            1. Change `dendritic-slop` for shared resources, or the consuming flake for host selection and secrets. Do not mutate runtime configuration or use `pi install`.
            2. Pin and review external packages, skills, and extensions before enabling them.
            3. Keep credentials and transient state outside the Nix store.
            4. Format changed Nix files and run `nix flake check --no-eval-cache --no-build --all-systems`.

            Project-local configuration may still be changed when explicitly requested.

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
