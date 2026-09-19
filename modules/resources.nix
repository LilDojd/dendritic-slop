{ config, lib, ... }:
let
  catalog = config.dendriticSlopInternal.catalog;
  inherit (config.flake.lib)
    mkSkillTree
    realizeHerdrPlugins
    realizePiPackages
    realizeProfile
    realizeSkills
    resourceAssertions
    ;
  piModule = config.flake.modules.homeManager.pi;

  resourceOptions =
    resources:
    lib.mapAttrs (_: resource: {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable ${resource.title}. ${resource.description}";
      };
    }) resources;

  profileOptions = lib.mapAttrs (_: profile: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the ${profile.title} profile. ${profile.description}";
    };
  }) catalog.profiles;

  targetModule =
    {
      config,
      lib,
      options,
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
      ) catalog.extensions;
      mcpSelection = config.dendriticSlop.mcps or { };
      enabledMcps = lib.filterAttrs (
        name: _: builtins.hasAttr name mcpSelection && mcpSelection.${name}.enable
      ) catalog.mcps;
      enabledTools = lib.filterAttrs (name: _: config.dendriticSlop.tools.${name}.enable) catalog.tools;
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
      enabledResources = {
        extensions = enabledExtensions;
        mcps = enabledMcps;
        skills = enabledSkills;
        tools = enabledTools;
        herdrPlugins = lib.filterAttrs (
          name: _: config.dendriticSlop.herdr.plugins.${name}.enable or false
        ) catalog.herdrPlugins;
      };
      allEnabled = lib.concatMap builtins.attrValues (
        builtins.attrValues (builtins.removeAttrs enabledResources [ "herdrPlugins" ])
      );
      requiredTargets = lib.unique (lib.concatMap (resource: resource.requiresTargets) allEnabled);
      realizedPiPackages = realizePiPackages {
        extensions = enabledExtensions;
        inherit pkgs;
      };
      pathExtensions = lib.filterAttrs (
        _: resource: resource.realization.type == "path"
      ) enabledExtensions;
      extensionEnvironment = lib.mkMerge (
        map (
          extension: lib.mapAttrs (_: declaration: { inherit (declaration) value; }) extension.environment
        ) (builtins.attrValues enabledExtensions)
      );
      availableTargets = builtins.attrNames (options.dendriticSlop.targets or { });
      profileDefaults = lib.mapAttrsToList (
        name: profile:
        lib.mkIf config.dendriticSlop.profiles.${name}.enable {
          dendriticSlop = {
            targets = lib.genAttrs (lib.intersectLists availableTargets profile.targets) (_: {
              enable = lib.mkDefault true;
            });
            skills = lib.genAttrs profile.members.skills (_: {
              enable = lib.mkDefault true;
            });
            extensions = lib.genAttrs profile.members.extensions (_: {
              enable = lib.mkDefault true;
            });
            tools = lib.genAttrs profile.members.tools (_: {
              enable = lib.mkDefault true;
            });
          }
          // lib.optionalAttrs (options.dendriticSlop ? mcps) {
            mcps = lib.genAttrs profile.members.mcps (_: {
              enable = lib.mkDefault true;
            });
          }
          // lib.optionalAttrs (options.dendriticSlop ? herdr) {
            herdr.plugins = lib.genAttrs profile.members.herdrPlugins (_: {
              enable = lib.mkDefault true;
            });
          };
        }
      ) catalog.profiles;
      pathExtensionFiles = lib.mapAttrs' (
        _: resource:
        lib.nameValuePair resource.realization.destination {
          source = resource.realization.source;
          force = true;
        }
      ) pathExtensions;
    in
    {
      options.dendriticSlop = {
        profiles = profileOptions;
        skills = resourceOptions catalog.skills;
        extensions = resourceOptions catalog.extensions;
        tools = resourceOptions catalog.tools;
      };

      config = lib.mkMerge (
        profileDefaults
        ++ [
          (lib.mkIf config.dendriticSlop.enable {
            assertions = resourceAssertions {
              inherit catalog pkgs;
              selected = enabledResources;
              selectedTargets = builtins.attrNames (
                lib.filterAttrs (_: target: target.enable) config.dendriticSlop.targets
              );
            };

            dendriticSlop.targets = lib.genAttrs requiredTargets (_: {
              enable = lib.mkDefault true;
            });

            home = {
              file = pathExtensionFiles // {
                ".agents/skills".source = managedSkills;
              };
              # Target modules own target-bound tools (including Pi's wrapper).
              packages =
                skillRuntimePackages
                ++ map (tool: tool.package pkgs) (
                  lib.filter (tool: tool.requiresTargets == [ ]) (builtins.attrValues enabledTools)
                );
            };

            programs.pi.coding-agent = {
              settings.packages = realizedPiPackages.settingsPackages;
              environment = extensionEnvironment;
            };
          })
        ]
      );
    };
in
{
  options.dendriticSlopInternal.realized = {
    extensions = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      internal = true;
    };
    herdrPlugins = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      internal = true;
    };
    profiles = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      internal = true;
    };
    skills = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      internal = true;
    };
  };

  config = {
    dendriticSlopInternal = {
      homeManagerTargets = [ targetModule ];
      realized = {
        extensions =
          pkgs:
          realizePiPackages {
            inherit (catalog) extensions;
            inherit pkgs;
          };
        herdrPlugins =
          pkgs:
          realizeHerdrPlugins {
            plugins = catalog.herdrPlugins;
            inherit pkgs;
          };
        profiles =
          pkgs:
          let
            realizedExtensions = realizePiPackages {
              inherit (catalog) extensions;
              inherit pkgs;
            };
            realizedHerdrPlugins = realizeHerdrPlugins {
              plugins = catalog.herdrPlugins;
              inherit pkgs;
            };
            realizedSkills = realizeSkills { inherit catalog pkgs; };
          in
          lib.mapAttrs (
            profileName: _:
            realizeProfile {
              inherit
                catalog
                pkgs
                profileName
                realizedExtensions
                realizedHerdrPlugins
                realizedSkills
                ;
            }
          ) catalog.profiles;
        skills = pkgs: realizeSkills { inherit catalog pkgs; };
      };
    };

    flake.modules.homeManager.resources.imports = [
      piModule
      targetModule
    ];

    perSystem =
      { pkgs, ... }:
      let
        realized = realizeSkills { inherit catalog pkgs; };
        realizedExtensions = realizePiPackages {
          inherit (catalog) extensions;
          inherit pkgs;
        };
        realizedHerdrPlugins = realizeHerdrPlugins {
          plugins = catalog.herdrPlugins;
          inherit pkgs;
        };
        profilePackages = lib.mapAttrs (
          profileName: _:
          realizeProfile {
            inherit
              catalog
              pkgs
              profileName
              realizedExtensions
              realizedHerdrPlugins
              ;
            realizedSkills = realized;
          }
        ) catalog.profiles;
      in
      {
        packages =
          lib.mapAttrs' (name: package: lib.nameValuePair "skill-${name}" package) realized.packages
          // lib.mapAttrs' (
            name: extension: lib.nameValuePair "extension-${name}" (extension.realization.package pkgs)
          ) (lib.filterAttrs (_: extension: extension.realization.type == "package") catalog.extensions)
          // lib.mapAttrs' (name: tool: lib.nameValuePair "tool-${name}" (tool.package pkgs)) catalog.tools
          // lib.mapAttrs' (
            name: plugin: lib.nameValuePair "herdr-plugin-${name}" plugin.root
          ) realizedHerdrPlugins
          // lib.mapAttrs' (name: package: lib.nameValuePair "all-${name}" package) profilePackages
          // {
            all-skills = realized.tree;
          };
      };
  };
}
