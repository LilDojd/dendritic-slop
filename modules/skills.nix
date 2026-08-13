{ config, ... }:
let
  piModule = config.flake.modules.homeManager.pi;
  inherit (config.flake.lib) mkEnableTarget mkSkill;
  skillText = name: builtins.readFile (../skills + "/${name}/SKILL.md");

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.dendriticSlop.targets.skills.enable = mkEnableTarget {
        inherit config lib;
        description = "Enable the bundled Pi skills.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.skills.enable) {
        dendriticSlop.targets.pi.enable = lib.mkDefault true;
        programs.pi.coding-agent.skills =
          map
            (
              name:
              mkSkill {
                inherit pkgs name;
                text = skillText name;
              }
            )
            [
              "bro"
              "jujutsu"
            ];
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.skills.imports = [
    piModule
    targetModule
  ];
}
