{ config, lib, ... }:
let
  catalog = config.dendriticSlopInternal.catalog;
  targetModule =
    { config, pkgs, ... }:
    let
      package = catalog.tools.firstmate.package pkgs;
      code = "${package}/share/firstmate";
      home = "${config.xdg.dataHome}/firstmate";
    in
    {
      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.tools.firstmate.enable) {
        home.packages = [ package ];
        home.file =
          lib.listToAttrs (
            map
              (
                path:
                lib.nameValuePair "${home}/${path}" {
                  source = "${code}/${path}";
                }
              )
              [
                "AGENTS.md"
                "README.md"
                "CONTRIBUTING.md"
                ".tasks.toml"
                "bin"
                "docs"
                ".agents/skills"
                ".pi/extensions"
              ]
          )
          // {
            "${home}/config/crew-harness".text = "pi\n";
            "${home}/config/secondmate-harness".text = "pi\n";
            "${home}/no-mistakes/config.yaml".text = "agent: pi\n";
          };
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.firstmate.imports = [
    config.flake.modules.homeManager.pi
    config.flake.modules.homeManager.herdr
    targetModule
  ];
}
