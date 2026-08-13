{ config, ... }:
let
  inherit (config.flake.lib) targetNames;
  homeManagerSlop = {
    imports = [
      config.flake.modules.homeManager.core
    ]
    ++ config.dendriticSlopInternal.homeManagerTargets;
  };

  bridge =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop;
      homeTargets = builtins.removeAttrs cfg.targets [ "persistence" ];
    in
    {
      options.dendriticSlop = {
        enable = lib.mkEnableOption "declarative Pi and LLM tooling";

        autoEnable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Automatically enable every imported target.";
        };

        username = lib.mkOption {
          type = lib.types.str;
          description = "Home Manager user receiving dendritic-slop.";
        };

        context7ApiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Absolute runtime path to the Context7 API key file.";
        };

        targets = lib.genAttrs (targetNames ++ [ "persistence" ]) (name: {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Override automatic activation of the ${name} target.";
          };
        });
      };

      config.home-manager.users.${cfg.username}.imports = [
        homeManagerSlop
        {
          dendriticSlop = {
            inherit (cfg) enable autoEnable;
            context7.apiKeyFile = cfg.context7ApiKeyFile;
            targets = lib.mapAttrs (
              _: value: lib.optionalAttrs (value.enable != null) { inherit (value) enable; }
            ) homeTargets;
          };
        }
      ];
    };
in
{
  flake.modules.homeManager.slop = homeManagerSlop;
  flake.modules.nixos.slop = {
    imports = [
      bridge
      config.flake.modules.nixos.persistence
    ];
  };
  flake.modules.darwin.slop = bridge;
}
