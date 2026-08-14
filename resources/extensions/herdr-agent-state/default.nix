{ inputs }:
{
  title = "Herdr Pi integration";
  description = "Report Pi session identity and working, blocked, and idle states to Herdr.";
  homepage = "https://github.com/herdrdev/herdr";
  fileName = "herdr-agent-state.ts";
  source = inputs.herdr + "/src/integration/assets/pi/herdr-agent-state.ts";
  requiresTargets = [ "herdr" ];
}
