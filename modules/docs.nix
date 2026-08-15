{
  config,
  lib,
  self,
  ...
}:
let
  catalog = config.dendriticSlopInternal.catalog;

  optionFor =
    kind: name:
    if kind == "herdrPlugins" then
      "dendriticSlop.herdr.plugins.${name}.enable"
    else
      "dendriticSlop.${kind}.${name}.enable";
  kindTitle =
    kind:
    {
      skills = "Skills";
      mcps = "MCP servers";
      extensions = "Pi extensions";
      tools = "Tools";
      herdrPlugins = "Herdr plugins";
    }
    .${kind};
  resourceKinds = [
    "skills"
    "mcps"
    "extensions"
    "tools"
    "herdrPlugins"
  ];
  listText = values: if values == [ ] then "None" else lib.concatStringsSep ", " values;
  capabilityText =
    capabilities: listText (builtins.attrNames (lib.filterAttrs (_: enabled: enabled) capabilities));
  profilesFor =
    resource: if resource.profiles == [ ] then "None" else lib.concatStringsSep ", " resource.profiles;

  kindDetails =
    kind: resource:
    if kind == "skills" then
      "- Exposed name: `${resource.exposedName}`"
    else if kind == "mcps" then
      ''
        - Server ID: `${resource.serverId}`
        - Transport: `${resource.transport.type}`
      ''
    else if kind == "extensions" then
      "- Realization: `${resource.realization.type}`"
    else if kind == "tools" then
      "- Executable: `${resource.executable}`"
    else
      ''
        - Plugin ID: `${resource.pluginId}`
        - Version: `${resource.version}`
        - Minimum Herdr version: `${resource.minimumHerdrVersion}`
        - Executable: `${resource.executable}`
        - Actions: ${listText (map (action: "`${action.id}`") resource.actions)}
        - Keys: ${listText (map (binding: "`${binding.key}`") resource.keybindings)}
      '';

  renderKind =
    kind:
    let
      resources = catalog.${kind};
    in
    ''
      ## ${kindTitle kind}

      ${lib.concatMapStringsSep "\n" (
        name:
        let
          resource = resources.${name};
        in
        ''
          ### ${resource.title}

          ${resource.description}

          - Option: `${optionFor kind name}`
          - Activation: disabled unless selected by a profile or explicit leaf setting
          - Profiles: ${profilesFor resource}
          - Required targets: ${listText resource.requiresTargets}
          - Required resources: ${listText resource.requiresResources}
          - Capabilities: ${capabilityText resource.capabilities}
          ${kindDetails kind resource}
          ${lib.optionalString (
            resource.repository != null
          ) "- Repository catalog ID: `${resource.repository}`"}
          ${lib.optionalString (
            resource.homepage != null
          ) "- Homepage: [${resource.homepage}](${resource.homepage})"}
        ''
      ) (builtins.attrNames resources)}
    '';

  profileRows = lib.concatMapStringsSep "\n" (
    name:
    let
      profile = catalog.profiles.${name};
      memberCount = builtins.length (lib.concatMap (kind: profile.members.${kind}) resourceKinds);
    in
    "| `${name}` | ${profile.description} | ${toString memberCount} | ${listText profile.targets} |"
  ) (builtins.attrNames catalog.profiles);

  catalogMarkdown = ''
    # Resource catalog

    The catalog is the current set of reviewed resources. Every leaf is disabled until an explicit profile or leaf setting selects it. Herdr plugins remain explicit opt-ins.

    ## Profiles

    | Profile | Description | Leaves | Targets |
    | --- | --- | ---: | --- |
    ${profileRows}

    ${lib.concatMapStringsSep "\n" renderKind resourceKinds}
  '';

  optionRows = lib.concatMapStringsSep "\n" (
    kind:
    lib.concatMapStringsSep "\n" (
      name:
      let
        resource = catalog.${kind}.${name};
      in
      "| `${optionFor kind name}` | Boolean | `false` | ${resource.title} |"
    ) (builtins.attrNames catalog.${kind})
  ) resourceKinds;
  profileOptionRows = lib.concatMapStringsSep "\n" (
    name:
    "| `dendriticSlop.profiles.${name}.enable` | Boolean | `false` | ${catalog.profiles.${name}.title} |"
  ) (builtins.attrNames catalog.profiles);

  optionsMarkdown = ''
    # Selection options

    Set `dendriticSlop.enable = true`, select profiles, and apply explicit leaf settings where needed. Explicit leaf and target values take precedence over profile defaults.

    | Option | Type | Default | Resource |
    | --- | --- | --- | --- |
    ${profileOptionRows}
    ${optionRows}

    MCP secret-file options are strings containing absolute runtime paths outside the Nix store. Their names are listed with each MCP leaf in the module option set.
  '';
in
{
  options.dendriticSlopInternal.docs = lib.mkOption {
    type = lib.types.submodule {
      options = {
        catalog = lib.mkOption { type = lib.types.str; };
        options = lib.mkOption { type = lib.types.str; };
      };
    };
    readOnly = true;
    internal = true;
  };

  config.dendriticSlopInternal.docs = {
    catalog = catalogMarkdown;
    options = optionsMarkdown;
  };

  config.perSystem =
    { pkgs, ... }:
    let
      generatedCatalog = pkgs.writeText "catalog.md" catalogMarkdown;
      generatedOptions = pkgs.writeText "options.md" optionsMarkdown;
      docs = pkgs.stdenvNoCC.mkDerivation {
        pname = "dendritic-slop-docs";
        version = self.shortRev or "dirty";
        src = ../docs;
        nativeBuildInputs = [ pkgs.mdbook ];
        patchPhase = ''
          runHook prePatch
          cp ${../README.md} src/index.md
          cp ${generatedCatalog} src/catalog.md
          cp ${generatedOptions} src/options.md
          runHook postPatch
        '';
        buildPhase = ''
          runHook preBuild
          mdbook build
          runHook postBuild
        '';
        installPhase = ''
          cp -r book "$out"
        '';
      };
    in
    {
      checks.docs = docs;
      packages.docs = docs;
      packages.resource-catalog = generatedCatalog;
      packages.option-reference = generatedOptions;
    };
}
