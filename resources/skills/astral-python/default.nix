{ inputs, ... }:
{
  title = "Astral Python skills";
  description = "Authoritative workflows for uv project management, Ruff linting and formatting, and ty type checking.";
  homepage = "https://github.com/astral-sh/claude-code-plugins";
  source = inputs.astral-agent-skills + "/plugins/astral/skills";
  collection = true;
  members = [
    "ruff"
    "ty"
    "uv"
  ];
  extraFiles = [
    (inputs.astral-agent-skills + "/LICENSE-APACHE")
    (inputs.astral-agent-skills + "/LICENSE-MIT")
  ];
  runtimeInputs = pkgs: [
    pkgs.ruff
    pkgs.ty
    pkgs.uv
  ];
}
