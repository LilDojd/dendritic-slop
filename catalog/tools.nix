{ inputs }:
let
  llmAgentPackage = name: pkgs: inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.${name};
  herdrSourceManifest = builtins.fromTOML (builtins.readFile (inputs.herdr-src + "/Cargo.toml"));
in
{
  herdr = {
    title = "Herdr";
    description = "Coordinate terminal coding-agent sessions.";
    homepage = "https://github.com/herdrdev/herdr";
    profiles = [ "core" ];
    requiresTargets = [ "herdr" ];
    capabilities.executesCode = true;
    package = llmAgentPackage "herdr";
    executable = "herdr";
    sourceVersion = herdrSourceManifest.package.version;
  };

  pi = {
    title = "Pi";
    description = "Run the extensible Pi terminal coding harness.";
    homepage = "https://github.com/earendil-works/pi";
    profiles = [ "core" ];
    requiresTargets = [ "pi" ];
    capabilities = {
      executesCode = true;
      network = true;
    };
    package = llmAgentPackage "pi";
    executable = "pi";
  };
}
