{ inputs, self, ... }:
{
  flake.modules.homeManager.pi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      packages = config.dendriticSlop.piPackages;
    in
    {
      imports = [ inputs.pi.homeModules.default ];

      options.dendriticSlop.piPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Pi packages written to `programs.pi.coding-agent.settings.packages`, which does not merge across modules.";
      };

      config = {
        dendriticSlop.piPackages = lib.mkIf (config.programs.mcp.servers != { }) [
          self.packages.${pkgs.stdenv.hostPlatform.system}.pi-mcp-adapter
        ];
        programs.pi.coding-agent = {
          package = lib.mkDefault inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
          settings = lib.mkIf (packages != [ ]) { packages = map toString (lib.unique packages); };
        };
      };
    };
}
