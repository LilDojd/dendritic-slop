{ config, lib, ... }:
let
  inherit (config.flake.lib) targetNames;
  catalog = config.dendriticSlopInternal.catalog;
  homeManagerSlop = {
    imports = [
      config.flake.modules.homeManager.core
    ]
    ++ config.dendriticSlopInternal.homeManagerTargets;
  };

  nullableResourceOptions =
    resources:
    lib.mapAttrs (_: resource: {
      enable = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Override profile selection of ${resource.title}.";
      };
    }) resources;

  nullableMcpOptions = lib.mapAttrs (_: resource: {
    enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override profile selection of ${resource.title}.";
    };
    secrets = lib.mapAttrs (
      _: secret:
      lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = secret.description;
      }
    ) resource.secretFiles;
  }) catalog.mcps;

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
        username = lib.mkOption {
          type = lib.types.str;
          description = "Home Manager user to configure.";
        };
        targets = lib.genAttrs (targetNames ++ [ "persistence" ]) (name: {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Override profile selection of the ${name} target.";
          };
        });
        profiles = nullableResourceOptions catalog.profiles;
        skills = nullableResourceOptions catalog.skills;
        mcps = nullableMcpOptions;
        extensions = nullableResourceOptions catalog.extensions;
        tools = nullableResourceOptions catalog.tools;
        herdr.plugins = nullableResourceOptions catalog.herdrPlugins;
        migrations.globalSkills.takeOver = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Back up existing global skill-manager state before Home Manager takes ownership.";
        };
      };

      config.home-manager.users.${cfg.username}.imports = [
        homeManagerSlop
        {
          dendriticSlop = {
            inherit (cfg) enable;
            targets = explicit homeTargets;
            profiles = explicit cfg.profiles;
            skills = explicit cfg.skills;
            mcps = lib.mapAttrs (
              _: value:
              lib.optionalAttrs (value.enable != null) { inherit (value) enable; }
              // {
                secrets = lib.filterAttrs (_: secretPath: secretPath != null) value.secrets;
              }
            ) cfg.mcps;
            extensions = explicit cfg.extensions;
            tools = explicit cfg.tools;
            herdr.plugins = explicit cfg.herdr.plugins;
            migrations.globalSkills.takeOver = cfg.migrations.globalSkills.takeOver;
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
