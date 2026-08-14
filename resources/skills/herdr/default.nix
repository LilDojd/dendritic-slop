{ inputs, ... }:
{
  title = "Herdr";
  description = "Inspect and control Herdr workspaces, tabs, panes, commands, and agents.";
  homepage = "https://github.com/herdrdev/herdr";
  source = inputs.herdr + "/skills/herdr/SKILL.md";
  requiresTargets = [ "herdr" ];
}
