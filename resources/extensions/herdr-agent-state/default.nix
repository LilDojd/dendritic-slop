{ inputs }:
{
  title = "Herdr agent state";
  description = "Expose Pi lifecycle state to Herdr.";
  homepage = "https://github.com/herdrdev/herdr";
  source = inputs.herdr + "/src/integration/assets/pi/herdr-agent-state.ts";
  requiresTargets = [ "herdr" ];
}
