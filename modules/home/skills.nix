{
  flake.modules.homeManager.skills =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      skills = config.dendriticSlop.skills;
    in
    {
      options.dendriticSlop.skills = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Agent skill directories by name, installed for Claude Code and in ~/.agents/skills.";
      };

      config = lib.mkIf (skills != { }) {
        programs.claude-code.skills = skills;
        home.file.".agents/skills".source = pkgs.linkFarm "agent-skills" skills;
      };
    };
}
