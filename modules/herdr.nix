{ config, inputs, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  inherit (config.flake.lib) mkEnableTarget;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.dendriticSlop.targets.herdr.enable = mkEnableTarget {
        inherit config lib;
        description = "Install Herdr.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.herdr.enable) {
        home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr ];
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.herdr.imports = [
    coreModule
    targetModule
  ];
}
