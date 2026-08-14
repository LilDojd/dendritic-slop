{
  config,
  inputs,
  lib,
  ...
}:
let
  legacy = config.dendriticSlopInternal.resources;
  profileDeclarations = import ../catalog/profiles.nix;
  repositories = import ../catalog/repositories.nix { inherit inputs; };
  skills = import ../catalog/skills.nix { inherit inputs; };
  projectionSkills = lib.mapAttrs (
    _: skill:
    skill
    // {
      repository = skill.repository or null;
      runtimeExecutables = skill.runtimeExecutables or [ ];
      runtimePackages = skill.runtimePackages or (_: [ ]);
    }
  ) skills;
  superpowersPackage =
    pkgs:
    config.flake.lib.mkRepositoryProjection {
      inherit pkgs;
      skills = projectionSkills;
      name = "superpowers";
      repository = repositories.superpowers;
      leafPaths = map (skill: skill.repositoryPath) (
        lib.filter (skill: (skill.repository or null) == "superpowers") (builtins.attrValues skills)
      );
    };
  extensions = import ../catalog/extensions.nix { inherit inputs superpowersPackage; };
  tools = import ../catalog/tools.nix { inherit inputs; };
  resourceKinds = [
    "skills"
    "mcps"
    "extensions"
    "tools"
    "herdrPlugins"
  ];

  emptyMembers = lib.genAttrs resourceKinds (_: [ ]);
  profiles = lib.mapAttrs (
    _: profile:
    profile
    // {
      targets = profile.targets or [ ];
      members = emptyMembers // (profile.members or { });
    }
  ) profileDeclarations;

  profilesFor =
    kind: name:
    builtins.attrNames (
      lib.filterAttrs (_: profile: builtins.elem name profile.members.${kind}) profiles
    );

  common = kind: name: resource: {
    inherit (resource) title description;
    homepage = resource.homepage or null;
    repository = resource.repository or null;
    defaultEnable = resource.defaultEnable;
    profiles = profilesFor kind name;
    requiresTargets = resource.requiresTargets or [ ];
  };

  legacyHerdrPlugins = lib.mapAttrs (
    name: resource:
    common "herdrPlugins" name resource
    // {
      inherit (resource)
        actions
        keybindings
        package
        pluginRoot
        version
        ;
      pluginId = resource.id;
      minimumHerdrVersion = "0.7.0";
    }
  ) legacy.herdrPlugins;

  declarations = {
    inherit
      extensions
      profiles
      repositories
      skills
      tools
      ;
    mcps = { };
    herdrPlugins = legacyHerdrPlugins;
  };

  referencesExist = lib.all (
    profile:
    lib.all (
      kind: lib.all (name: builtins.hasAttr name declarations.${kind}) profile.members.${kind}
    ) resourceKinds
  ) (builtins.attrValues profiles);

  repositoriesExist = lib.all (
    kind:
    lib.all (
      resource: (resource.repository or null) == null || builtins.hasAttr resource.repository repositories
    ) (builtins.attrValues declarations.${kind})
  ) resourceKinds;

  listsAreUnique = lib.all (
    profile:
    lib.all (kind: lib.unique profile.members.${kind} == profile.members.${kind}) resourceKinds
    && lib.unique profile.targets == profile.targets
  ) (builtins.attrValues profiles);

  profileMetadataAgrees = lib.all (
    kind:
    lib.all (name: declarations.${kind}.${name}.profiles == profilesFor kind name) (
      builtins.attrNames declarations.${kind}
    )
  ) resourceKinds;

  catalog =
    assert lib.assertMsg referencesExist "A profile refers to an unknown typed resource leaf";
    assert lib.assertMsg repositoriesExist "A typed resource refers to an unknown repository";
    assert lib.assertMsg listsAreUnique "Profile target and resource memberships must be unique";
    assert lib.assertMsg profileMetadataAgrees
      "Resource profile metadata must match canonical profiles";
    declarations;
in
{
  options.dendriticSlopInternal.catalog = lib.mkOption {
    type = config.dendriticSlopInternal.resourceSchema.catalogType;
    readOnly = true;
    internal = true;
  };

  config.dendriticSlopInternal.catalog = catalog;
}
