{ lib, ... }:
let
  targetNames = [
    "context7"
    "git"
    "herdr"
    "pi"
    "rules"
  ];

  isValidSkillName =
    name:
    builtins.isString name
    && builtins.stringLength name <= 64
    && builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null;

  resourceKinds = [
    "skills"
    "mcps"
    "extensions"
    "tools"
    "herdrPlugins"
  ];

  evalResourceSelection =
    {
      catalog,
      selection ? { },
    }:
    let
      declaredTargets = lib.unique (
        targetNames
        ++ lib.concatMap (profile: profile.targets) (builtins.attrValues catalog.profiles)
        ++ lib.concatMap (
          kind: lib.concatMap (resource: resource.requiresTargets) (builtins.attrValues catalog.${kind})
        ) resourceKinds
      );
      targets = lib.genAttrs declaredTargets (_: { });
      selectionOptions =
        type: default: values:
        lib.mapAttrs (
          _: _:
          lib.mkOption {
            inherit type default;
          }
        ) values;
      optionsFor = type: default: {
        profiles = selectionOptions type default catalog.profiles;
        targets = selectionOptions type default targets;
        skills = selectionOptions type default catalog.skills;
        mcps = selectionOptions type default catalog.mcps;
        extensions = selectionOptions type default catalog.extensions;
        tools = selectionOptions type default catalog.tools;
        herdrPlugins = selectionOptions type default catalog.herdrPlugins;
      };
      overrideModule = {
        options = optionsFor (lib.types.nullOr lib.types.bool) null;
        config = selection;
      };
      overrides = (lib.evalModules { modules = [ overrideModule ]; }).config;
      explicitValues = values: lib.filterAttrs (_: value: value != null) values;
      explicitSelection = {
        profiles = explicitValues overrides.profiles;
        targets = explicitValues overrides.targets;
        skills = explicitValues overrides.skills;
        mcps = explicitValues overrides.mcps;
        extensions = explicitValues overrides.extensions;
        tools = explicitValues overrides.tools;
        herdrPlugins = explicitValues overrides.herdrPlugins;
      };
      effectiveModule =
        { config, ... }:
        {
          options = optionsFor lib.types.bool false;
          config = lib.mkMerge (
            [ explicitSelection ]
            ++ lib.mapAttrsToList (
              profileName: profile:
              lib.mkIf config.profiles.${profileName} (
                {
                  targets = lib.genAttrs profile.targets (_: lib.mkDefault true);
                }
                // lib.genAttrs resourceKinds (kind: lib.genAttrs profile.members.${kind} (_: lib.mkDefault true))
              )
            ) catalog.profiles
          );
        };
      effective = (lib.evalModules { modules = [ effectiveModule ]; }).config;
    in
    {
      inherit effective overrides;
    };

  resolveResources =
    {
      catalog,
      selection,
      pkgs,
    }:
    let
      inherit (selection) effective overrides;
      enabledNames = values: builtins.attrNames (lib.filterAttrs (_: enabled: enabled) values);
      enabledProfiles = enabledNames effective.profiles;
      selectedTargets = enabledNames effective.targets;
      selected = lib.genAttrs resourceKinds (
        kind: lib.filterAttrs (name: _: effective.${kind}.${name}) catalog.${kind}
      );
      entriesFor =
        resources:
        lib.concatMap (
          kind:
          lib.mapAttrsToList (name: resource: {
            reference = "${kind}.${name}";
            inherit kind name resource;
          }) resources.${kind}
        ) resourceKinds;
      allEntries = entriesFor catalog;
      allReferences = map (entry: entry.reference) allEntries;
      selectedEntries = entriesFor selected;
      selectedReferences = map (entry: entry.reference) selectedEntries;
      requirementsByReference = builtins.listToAttrs (
        map (entry: lib.nameValuePair entry.reference entry.resource.requiresResources) allEntries
      );
      hasRequirementCycle =
        start:
        let
          visit =
            path: reference:
            if builtins.elem reference path then
              true
            else
              lib.any (visit (path ++ [ reference ])) (requirementsByReference.${reference} or [ ]);
        in
        visit [ ] start;

      profileOrigins =
        kind: name:
        lib.filter (
          profileName: builtins.elem name catalog.profiles.${profileName}.members.${kind}
        ) enabledProfiles;
      originText =
        kind: name:
        let
          origins = profileOrigins kind name;
        in
        if origins == [ ] then
          "explicit leaf selection"
        else
          "profile ${lib.concatStringsSep ", " origins}";

      declaredRequirementChecks = lib.concatMap (
        entry:
        map (requirement: {
          assertion = builtins.elem requirement allReferences;
          message = "${entry.reference} requires unknown resource ${requirement}";
        }) entry.resource.requiresResources
        ++ [
          {
            assertion = !hasRequirementCycle entry.reference;
            message = "${entry.reference} participates in a resource requirement cycle";
          }
        ]
      ) allEntries;

      requirementChecks = lib.concatMap (
        entry:
        map (target: {
          assertion = builtins.elem target selectedTargets;
          message = "${entry.reference} selected by ${originText entry.kind entry.name} requires ${
            if overrides.targets.${target} == false then "explicitly disabled" else "disabled"
          } target ${target}; enable targets.${target} or disable ${entry.reference}";
        }) entry.resource.requiresTargets
        ++ map (
          requirement:
          let
            requiredEntry = lib.findFirst (candidate: candidate.reference == requirement) null allEntries;
            explicitlyDisabled =
              requiredEntry != null && overrides.${requiredEntry.kind}.${requiredEntry.name} == false;
          in
          {
            assertion = builtins.elem requirement selectedReferences;
            message = "${entry.reference} selected by ${originText entry.kind entry.name} requires ${
              if explicitlyDisabled then "explicitly disabled" else "disabled"
            } resource ${requirement}; enable ${requirement} or disable ${entry.reference}";
          }
        ) entry.resource.requiresResources
      ) selectedEntries;

      packagesFor =
        entry:
        if entry.kind == "skills" then
          let
            runtimePackages = entry.resource.runtimePackages pkgs;
          in
          assert lib.assertMsg (builtins.isList runtimePackages)
            "${entry.reference}.runtimePackages must return a list";
          runtimePackages ++ map (runtime: runtime.package pkgs) entry.resource.runtimeExecutables
        else if entry.kind == "mcps" && entry.resource.transport.type == "local" then
          [ (entry.resource.transport.package pkgs) ]
        else if entry.kind == "extensions" && entry.resource.realization.type == "package" then
          [ (entry.resource.realization.package pkgs) ]
        else if entry.kind == "tools" then
          [ (entry.resource.package pkgs) ]
        else if entry.kind == "herdrPlugins" then
          [
            (entry.resource.package pkgs)
            (entry.resource.pluginRoot pkgs)
          ]
        else
          [ ];
      packageAvailable =
        entry: package:
        if lib.isDerivation package then
          lib.meta.availableOn pkgs.stdenv.hostPlatform package
        else
          entry.kind == "extensions";
      platformChecks = map (
        entry:
        let
          packages = packagesFor entry;
        in
        {
          assertion =
            (
              entry.resource.platforms == null
              || builtins.elem pkgs.stdenv.hostPlatform.system entry.resource.platforms
            )
            && lib.all (packageAvailable entry) packages;
          message = "${entry.reference} has no package available on ${pkgs.stdenv.hostPlatform.system}";
        }
      ) selectedEntries;

      occurrences =
        key: entries:
        lib.foldl' (
          result: entry:
          let
            value = key entry;
          in
          if value == null then
            result
          else
            result // { ${value} = (result.${value} or [ ]) ++ [ entry.reference ]; }
        ) { } entries;
      duplicateValues = values: lib.filterAttrs (_: references: builtins.length references > 1) values;
      collisionCheck =
        label: values:
        let
          duplicates = duplicateValues values;
          duplicateNames = builtins.attrNames duplicates;
          duplicateName = if duplicateNames == [ ] then "" else builtins.head duplicateNames;
        in
        {
          assertion = duplicateNames == [ ];
          message =
            if duplicateNames == [ ] then
              ""
            else
              "${label} ${duplicateName} is exposed by ${lib.concatStringsSep ", " duplicates.${duplicateName}}";
        };
      skillEntries = lib.filter (entry: entry.kind == "skills") selectedEntries;
      mcpEntries = lib.filter (entry: entry.kind == "mcps") selectedEntries;
      extensionEntries = lib.filter (entry: entry.kind == "extensions") selectedEntries;
      pluginEntries = lib.filter (entry: entry.kind == "herdrPlugins") selectedEntries;
      bindingEntries = lib.concatMap (
        entry:
        map (binding: {
          reference = entry.reference;
          inherit binding;
        }) entry.resource.keybindings
      ) pluginEntries;
      collisionChecks = [
        (collisionCheck "Skill exposed name" (occurrences (entry: entry.resource.exposedName) skillEntries))
        (collisionCheck "MCP server ID" (occurrences (entry: entry.resource.serverId) mcpEntries))
        (collisionCheck "Extension destination" (
          occurrences (
            entry:
            if entry.resource.realization.type == "path" then entry.resource.realization.destination else null
          ) extensionEntries
        ))
        (collisionCheck "Herdr plugin ID" (occurrences (entry: entry.resource.pluginId) pluginEntries))
        (collisionCheck "Herdr keybinding" (occurrences (entry: entry.binding.key) bindingEntries))
      ];

      checks = declaredRequirementChecks ++ requirementChecks ++ platformChecks ++ collisionChecks;
      validated = lib.foldl' (
        result: check:
        assert lib.assertMsg check.assertion check.message;
        result
      ) true checks;
    in
    assert validated;
    {
      profiles = enabledProfiles;
      targets = selectedTargets;
      selection = {
        inherit effective overrides;
      };
      inherit (selected)
        skills
        mcps
        extensions
        tools
        herdrPlugins
        ;
    };

  mkSkill =
    {
      pkgs,
      name,
      source,
      collection ? false,
      extraFiles ? [ ],
      members ? [ ],
      runtimeInputs ? [ ],
    }:
    assert lib.assertMsg (isValidSkillName name)
      "Skill names must be lowercase alphanumeric words separated by single hyphens";
    assert lib.assertMsg (builtins.pathExists source) "Skill source does not exist";
    assert lib.assertMsg (builtins.isBool collection) "Skill collection must be a Boolean";
    assert lib.assertMsg (
      builtins.isList members && builtins.all isValidSkillName members && (members == [ ] || collection)
    ) "Skill members must be valid names in a collection";
    assert lib.assertMsg (builtins.all (
      member: builtins.pathExists (source + "/${member}/SKILL.md")
    ) members) "A skill collection member does not exist";
    assert lib.assertMsg (builtins.all builtins.pathExists extraFiles)
      "A skill extra file does not exist";
    assert lib.assertMsg (builtins.all lib.isDerivation runtimeInputs)
      "Skill runtime inputs must be packages";
    let
      sourcePath = builtins.path {
        path = source;
        name = "agent-skill-${name}-source";
      };
      copiedExtraFiles = map (
        file:
        let
          fileName = builtins.unsafeDiscardStringContext (builtins.baseNameOf file);
        in
        {
          name = fileName;
          path = builtins.path {
            path = file;
            name = "agent-skill-${name}-${fileName}";
          };
        }
      ) extraFiles;
    in
    pkgs.runCommand "agent-skill-${name}"
      {
        nativeBuildInputs = runtimeInputs;
        passthru = { inherit runtimeInputs; };
      }
      ''
        destination=${if collection then ''"$out"'' else ''"$out/${name}"''}
        mkdir -p "$destination"
        if [ -d ${lib.escapeShellArg sourcePath} ]; then
          ${
            if members == [ ] then
              ''cp -R ${lib.escapeShellArg "${sourcePath}/."} "$destination/"''
            else
              lib.concatMapStringsSep "\n" (member: ''
                cp -R ${lib.escapeShellArg "${sourcePath}/${member}"} "$destination/${member}"
              '') members
          }
        else
          ${lib.optionalString collection "echo 'A skill collection source must be a directory' >&2; exit 1"}
          cp ${lib.escapeShellArg sourcePath} "$destination/SKILL.md"
        fi
        ${lib.concatMapStringsSep "\n" (file: ''
          cp ${lib.escapeShellArg file.path} "$destination/${file.name}"
        '') copiedExtraFiles}
        chmod -R u+w "$destination"
        patchShebangs "$destination"
        ${
          if collection then
            ''
              skill_count=0
              while IFS= read -r -d $'\0' target; do
                ${pkgs.gnugrep}/bin/grep -Eq '^name:[[:space:]]+[a-z0-9]+(-[a-z0-9]+)*[[:space:]]*$' "$target"
                ${pkgs.gnugrep}/bin/grep -Eq '^description:' "$target"
                skill_count=$((skill_count + 1))
              done < <(${pkgs.findutils}/bin/find "$destination" -name SKILL.md -type f -print0)
              test "$skill_count" -gt 0
            ''
          else
            ''
              target="$destination/SKILL.md"
              test -f "$target"
              ${pkgs.gnugrep}/bin/grep -Fqx -- ${lib.escapeShellArg "name: ${name}"} "$target"
              ${pkgs.gnugrep}/bin/grep -Eq '^description:' "$target"
            ''
        }
      '';
in
{
  options.dendriticSlopInternal.homeManagerTargets = lib.mkOption {
    type = lib.types.listOf lib.types.deferredModule;
    default = [ ];
    internal = true;
  };

  config.flake.lib = {
    inherit
      evalResourceSelection
      isValidSkillName
      mkSkill
      resolveResources
      resourceKinds
      targetNames
      ;

    mkEnableTarget =
      {
        config,
        lib,
        description,
      }:
      lib.mkOption {
        type = lib.types.bool;
        default = config.dendriticSlop.autoEnable;
        defaultText = lib.literalExpression "config.dendriticSlop.autoEnable";
        inherit description;
      };
  };
}
