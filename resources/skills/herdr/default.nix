{ inputs }:
{
  title = "Herdr";
  description = "Control Herdr workspaces, panes, and Pi agents.";
  homepage = "https://github.com/herdrdev/herdr";
  source = inputs.herdr + "/skills/herdr/SKILL.md";
  requiresTargets = [ "herdr" ];
}
