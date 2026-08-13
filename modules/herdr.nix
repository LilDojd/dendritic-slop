{ config, inputs, ... }:
let
  piModule = config.flake.modules.homeManager.pi;
  inherit (config.flake.lib) mkEnableTarget mkSkill;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.dendriticSlop.targets.herdr.enable = mkEnableTarget {
        inherit config lib;
        description = "Enable Herdr and its Pi integration.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.herdr.enable) {
        dendriticSlop.targets.pi.enable = lib.mkDefault true;
        home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr ];

        programs.pi.coding-agent = {
          skills = [
            (mkSkill {
              inherit pkgs;
              name = "herdr";
              text = builtins.readFile (inputs.herdr + "/skills/herdr/SKILL.md");
            })
          ];
          extensions = [ (inputs.herdr + "/src/integration/assets/pi/herdr-agent-state.ts") ];
        };
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.herdr.imports = [
    piModule
    targetModule
  ];
}
