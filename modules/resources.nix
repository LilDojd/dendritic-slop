{ config, lib, ... }:
let
  catalog = config.dendriticSlopInternal.catalog;
  legacyExtensions = config.dendriticSlopInternal.resources.extensions;
  inherit (config.flake.lib) mkSkillTree realizeSkills;
  piModule = config.flake.modules.homeManager.pi;

  resourceOptions =
    hmConfig: resources:
    lib.mapAttrs (_: resource: {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = resource.defaultEnable && hmConfig.dendriticSlop.autoEnable;
        defaultText = lib.literalExpression (
          if resource.defaultEnable then "config.dendriticSlop.autoEnable" else "false"
        );
        description = "Whether to enable ${resource.title}. ${resource.description}";
      };
    }) resources;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      realized = realizeSkills { inherit catalog pkgs; };
      enabledSkills = lib.filterAttrs (
        name: _: config.dendriticSlop.skills.${name}.enable
      ) catalog.skills;
      enabledExtensions = lib.filterAttrs (
        name: _: config.dendriticSlop.extensions.${name}.enable
      ) legacyExtensions;
      selectedTargets = lib.filterAttrs (name: _: builtins.hasAttr name enabledSkills) realized.targets;
      managedSkills = mkSkillTree {
        inherit pkgs;
        name = "dendritic-slop-selected-agent-skills";
        targets = selectedTargets;
      };
      skillRuntimePackages = lib.unique (
        lib.concatMap (name: realized.realizedLeaves.${name}.runtimePackages) (
          builtins.attrNames enabledSkills
        )
      );
      allEnabled = builtins.attrValues enabledSkills ++ builtins.attrValues enabledExtensions;
      requiredTargets = lib.unique (lib.concatMap (resource: resource.requiresTargets) allEnabled);
      packageResources = lib.filter (resource: resource ? package) (
        builtins.attrValues enabledExtensions
      );
      pathExtensions = lib.filterAttrs (_: resource: resource ? source) enabledExtensions;
      pathExtensionFiles = lib.mapAttrs' (
        _: resource:
        lib.nameValuePair ".pi/agent/extensions/${resource.fileName}" {
          source = resource.source;
          force = true;
        }
      ) pathExtensions;
    in
    {
      options.dendriticSlop = {
        skills = resourceOptions config catalog.skills;
        extensions = resourceOptions config legacyExtensions;
      };

      config = lib.mkIf config.dendriticSlop.enable {
        dendriticSlop.targets = lib.genAttrs requiredTargets (_: {
          enable = lib.mkDefault true;
        });

        home = {
          file = pathExtensionFiles // {
            ".agents/skills" = {
              source = managedSkills;
              force = true;
            };
          };
          packages = skillRuntimePackages;
        };

        programs.pi.coding-agent = {
          settings.packages = [
            # renovate: datasource=npm depName=pi-mcp-adapter
            "npm:pi-mcp-adapter@2.22.0"
          ]
          ++ map (resource: resource.package) packageResources;
          environment = lib.mkMerge (map (resource: resource.environment or { }) allEnabled);
        };
      };
    };
in
{
  options.dendriticSlopInternal.realized.skills = lib.mkOption {
    type = lib.types.functionTo lib.types.raw;
    readOnly = true;
    internal = true;
  };

  config = {
    dendriticSlopInternal = {
      homeManagerTargets = [ targetModule ];
      realized.skills = pkgs: realizeSkills { inherit catalog pkgs; };
    };

    flake.modules.homeManager.resources.imports = [
      piModule
      targetModule
    ];

    perSystem =
      { pkgs, ... }:
      let
        realized = realizeSkills { inherit catalog pkgs; };
      in
      {
        packages =
          lib.mapAttrs' (name: package: lib.nameValuePair "skill-${name}" package) realized.packages
          // {
            all-skills = realized.tree;
          };
      };
  };
}
