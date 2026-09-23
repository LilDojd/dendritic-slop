{ inputs, herdrSource }:
let
  llmAgentPackage = name: pkgs: inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.${name};
  herdrSourceManifest = builtins.fromTOML (builtins.readFile (herdrSource + "/Cargo.toml"));
in
{
  claude-code = {
    title = "Claude Code";
    description = "Run Anthropic's Claude Code terminal coding agent.";
    homepage = "https://github.com/anthropics/claude-code";

    requiresTargets = [ "claude" ];
    capabilities = {
      executesCode = true;
      network = true;
    };
    package = llmAgentPackage "claude-code";
    executable = "claude";
  };

  herdr = {
    title = "Herdr";
    description = "Coordinate terminal coding-agent sessions.";
    homepage = "https://github.com/herdrdev/herdr";

    requiresTargets = [ "herdr" ];
    capabilities.executesCode = true;
    package = llmAgentPackage "herdr";
    executable = "herdr";
    sourceVersion = herdrSourceManifest.package.version;
  };

  tsk = {
    title = "tsk";
    description = "Manage a shared task board from the terminal.";
    homepage = "https://github.com/smarzban/tsk";
    capabilities = {
      executesCode = true;
      network = true;
      mutatesUserConfig = true;
    };
    package = pkgs: pkgs.callPackage ../packages/tsk.nix { inherit (inputs) tsk; };
    executable = "tsk";
  };

  pi = {
    title = "Pi";
    description = "Run the extensible Pi terminal coding harness.";
    homepage = "https://github.com/earendil-works/pi";

    requiresTargets = [ "pi" ];
    capabilities = {
      executesCode = true;
      network = true;
    };
    package = llmAgentPackage "pi";
    executable = "pi";
  };
}
