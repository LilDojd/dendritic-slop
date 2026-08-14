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

  repositoryFor = {
    actionbook-rust = "actionbook-rust";
    astral-python = "astral-python";
    rust-skills = "leonardomso-rust-skills";
    superpowers = "superpowers";
  };

  repositoryPathFor =
    collectionName: leafName:
    if collectionName == "actionbook-rust" then
      "skills/${leafName}"
    else if collectionName == "astral-python" then
      "plugins/astral/skills/${leafName}"
    else if collectionName == "rust-skills" then
      "."
    else if collectionName == "superpowers" then
      "skills/${leafName}"
    else
      null;

  common = kind: name: resource: {
    inherit (resource) title description;
    homepage = resource.homepage or null;
    defaultEnable = resource.defaultEnable;
    repository = repositoryFor.${name} or null;
    profiles = profilesFor kind name;
    requiresTargets = resource.requiresTargets or [ ];
  };

  legacySkills = lib.foldlAttrs (
    result: collectionName: resource:
    let
      names = if resource.collection then resource.members else [ collectionName ];
    in
    result
    // lib.genAttrs names (
      name:
      common "skills" name resource
      // {
        repository = repositoryFor.${collectionName} or null;
        profiles = profilesFor "skills" name;
        exposedName = name;
        repositoryPath = repositoryPathFor collectionName name;
        runtimePackages = resource.runtimeInputs;
        source = if resource.collection then resource.source + "/${name}" else resource.source;
      }
    )
  ) { } legacy.skills;

  legacyExtensions = lib.mapAttrs (
    name: resource:
    common "extensions" name resource
    // {
      profiles = profilesFor "extensions" name;
      environment = resource.environment;
      realization =
        if resource ? source then
          {
            type = "path";
            inherit (resource) source;
            destination = ".pi/agent/extensions/${resource.fileName}";
          }
        else
          {
            type = "package";
            package = _: resource.package;
            packageId = name;
          };
    }
  ) legacy.extensions;

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
    inherit repositories profiles;
    skills = legacySkills;
    mcps = { };
    extensions = legacyExtensions;
    tools = { };
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
      resource: resource.repository == null || builtins.hasAttr resource.repository repositories
    ) (builtins.attrValues declarations.${kind})
  ) resourceKinds;

  listsAreUnique = lib.all (
    profile:
    lib.all (kind: lib.unique profile.members.${kind} == profile.members.${kind}) resourceKinds
    && lib.unique profile.targets == profile.targets
  ) (builtins.attrValues profiles);

  catalog =
    assert lib.assertMsg referencesExist "A profile refers to an unknown typed resource leaf";
    assert lib.assertMsg repositoriesExist "A typed resource refers to an unknown repository";
    assert lib.assertMsg listsAreUnique "Profile target and resource memberships must be unique";
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
