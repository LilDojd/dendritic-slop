{ inputs, herdrSource }:
let
  llmAgentPackage = name: pkgs: inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.${name};
  herdrSourceManifest = builtins.fromTOML (builtins.readFile (herdrSource + "/Cargo.toml"));
in
{
  firstmate = {
    title = "Firstmate";
    description = "Run an isolated Pi and Herdr orchestration workspace.";
    homepage = "https://github.com/kunchenguid/firstmate";
    requiresTargets = [
      "pi"
      "herdr"
    ];
    capabilities = {
      executesCode = true;
      network = true;
      readsSecrets = true;
      mutatesUserConfig = true;
    };
    package =
      pkgs:
      pkgs.callPackage ../packages/firstmate.nix {
        source = inputs.firstmate;
        treehouse = inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
    executable = "firstmate";
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
