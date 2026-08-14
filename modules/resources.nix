{ config, lib, ... }:
let
  inherit (config.dendriticSlopInternal) resources;
  inherit (config.flake.lib) mkSkill;
  piModule = config.flake.modules.homeManager.pi;

  resourceOptions =
    hmConfig: catalog:
    lib.mapAttrs (_: resource: {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = resource.defaultEnable && hmConfig.dendriticSlop.autoEnable;
        defaultText = lib.literalExpression (
          if resource.defaultEnable then "config.dendriticSlop.autoEnable" else "false"
        );
        description = "Whether to enable ${resource.title}. ${resource.description}";
      };
    }) catalog;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      enabled =
        kind: lib.filterAttrs (name: _: config.dendriticSlop.${kind}.${name}.enable) resources.${kind};
      enabledSkills = enabled "skills";
      enabledExtensions = enabled "extensions";
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
        skills = resourceOptions config resources.skills;
        extensions = resourceOptions config resources.extensions;
      };

      config = lib.mkIf config.dendriticSlop.enable {
        dendriticSlop.targets = lib.genAttrs requiredTargets (_: {
          enable = lib.mkDefault true;
        });

        home.file = pathExtensionFiles;

        programs.pi.coding-agent = {
          skills = lib.mapAttrsToList (
            name: resource:
            mkSkill {
              inherit pkgs name;
              text = builtins.readFile resource.source;
            }
          ) enabledSkills;

          settings.packages = [
            # renovate: datasource=npm depName=pi-mcp-adapter
            "npm:pi-mcp-adapter@2.22.0"
          ]
          ++ map (resource: resource.package) packageResources;
          environment = lib.mkMerge (map (resource: resource.environment) allEnabled);
        };
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.resources.imports = [
    piModule
    targetModule
  ];
}
