{ config, lib, ... }:
let
  inherit (config.flake.lib) targetNames;
  inherit (config.dendriticSlopInternal) resources;
  homeManagerSlop = {
    imports = [
      config.flake.modules.homeManager.core
    ]
    ++ config.dendriticSlopInternal.homeManagerTargets;
  };

  nullableResourceOptions =
    catalog:
    lib.mapAttrs (_: resource: {
      enable = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Override automatic activation of ${resource.title}.";
      };
    }) catalog;

  bridge =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop;
      homeTargets = builtins.removeAttrs cfg.targets [ "persistence" ];
      explicit =
        values:
        lib.mapAttrs (
          _: value: lib.optionalAttrs (value.enable != null) { inherit (value) enable; }
        ) values;
    in
    {
      options.dendriticSlop = {
        enable = lib.mkEnableOption "declarative Pi and LLM tooling";
        autoEnable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Automatically enable every imported target and resource.";
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
        skills = nullableResourceOptions resources.skills;
        extensions = nullableResourceOptions resources.extensions;
      };

      config.home-manager.users.${cfg.username}.imports = [
        homeManagerSlop
        {
          dendriticSlop = {
            inherit (cfg) enable autoEnable;
            context7.apiKeyFile = cfg.context7ApiKeyFile;
            targets = explicit homeTargets;
            skills = explicit cfg.skills;
            extensions = explicit cfg.extensions;
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
