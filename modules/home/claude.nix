{ inputs, ... }:
{
  flake.modules.homeManager.claude =
    { lib, pkgs, ... }:
    {
      programs.claude-code = {
        package = lib.mkDefault inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
        enableMcpIntegration = lib.mkDefault true;
        settings.env.DISABLE_AUTOUPDATER = "1";
      };
    };
}
