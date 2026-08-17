{ lib, ... }:
let
  targetNames = [
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
          [ (entry.resource.package pkgs) ]
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
        (collisionCheck "Herdr plugin source" (
          occurrences (entry: toString entry.resource.source) pluginEntries
        ))
        (collisionCheck "Herdr plugin ID" (occurrences (entry: entry.resource.pluginId) pluginEntries))
        (collisionCheck "Herdr plugin executable" (
          occurrences (entry: entry.resource.executable) pluginEntries
        ))
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

  mkRepositoryProjection =
    {
      pkgs,
      name,
      repository,
      leafPaths,
      skills,
    }:
    let
      allowedPaths = lib.unique (leafPaths ++ repository.supportPaths);
      sourceString = toString repository.source;
      filteredSource = builtins.path {
        path = repository.source;
        name = "reviewed-${name}-source";
        filter =
          path: _:
          let
            pathString = toString path;
            relative =
              if pathString == sourceString then "" else lib.removePrefix "${sourceString}/" pathString;
          in
          relative == ""
          || lib.any (
            allowed:
            relative == allowed || lib.hasPrefix "${allowed}/" relative || lib.hasPrefix "${relative}/" allowed
          ) allowedPaths;
      };
      packagingInputs = lib.unique (map (package: package pkgs) repository.buildInputs);
      immutablePatches = map (
        patchPath:
        builtins.path {
          path = patchPath;
          name = "reviewed-${name}-${builtins.baseNameOf patchPath}";
        }
      ) repository.patches;
      executableEntrypoints = lib.filter (
        entrypoint: entrypoint.type == "executable"
      ) repository.entrypoints;
      interpreterEntrypoints = lib.filter (
        entrypoint: entrypoint.type == "interpreter"
      ) repository.entrypoints;
      entrypointPackages =
        entrypoint:
        let
          owner = skills.${entrypoint.owner};
        in
        lib.unique (
          owner.runtimePackages pkgs ++ map (runtime: runtime.package pkgs) owner.runtimeExecutables
        );
      entrypointsAreOwned = lib.all (
        entrypoint:
        entrypoint.owner != null
        && builtins.hasAttr entrypoint.owner skills
        && skills.${entrypoint.owner}.repository == name
      ) repository.entrypoints;
    in
    assert lib.assertMsg entrypointsAreOwned
      "Every reviewed ${name} entrypoint must be owned by a leaf in that repository";
    if
      repository.entrypoints == [ ] && repository.ignoredEntrypoints == [ ] && repository.patches == [ ]
    then
      filteredSource
    else
      pkgs.runCommand "reviewed-${name}-projection"
        {
          nativeBuildInputs = packagingInputs;
          passthru = {
            inherit allowedPaths packagingInputs;
            entrypoints = repository.entrypoints;
          };
        }
        ''
          mkdir -p "$out"
          cp -R ${filteredSource}/. "$out/"
          chmod -R u+w "$out"

          ${lib.concatMapStringsSep "\n" (patch: ''
            patch --no-backup-if-mismatch -d "$out" -p1 < ${lib.escapeShellArg patch}
          '') immutablePatches}

          ${lib.concatMapStringsSep "\n" (path: ''
            test -f "$out/${path}"
            rm "$out/${path}"
          '') repository.ignoredEntrypoints}

          ${lib.concatMapStringsSep "\n" (entrypoint: ''
            test -f "$out/${entrypoint.path}"
            chmod +x "$out/${entrypoint.path}"
            patchShebangs "$out/${entrypoint.path}"
            wrapProgram "$out/${entrypoint.path}" \
              --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath (entrypointPackages entrypoint))}
          '') executableEntrypoints}

          ${lib.concatMapStringsSep "\n" (entrypoint: ''
            test -f "$out/${entrypoint.path}"
          '') interpreterEntrypoints}
        '';

  mkLocalSkillRoot =
    {
      pkgs,
      name,
      source,
    }:
    let
      immutableSource = builtins.path {
        path = source;
        name = "agent-skill-${name}-source";
      };
    in
    pkgs.runCommand "agent-skill-${name}-root" { } ''
      mkdir -p "$out"
      if [ -d ${immutableSource} ]; then
        cp -R ${immutableSource}/. "$out/"
      else
        cp ${immutableSource} "$out/SKILL.md"
      fi
    '';

  mkSkillLink =
    {
      pkgs,
      name,
      target,
      runtimePackages ? [ ],
      runtimeExecutables ? [ ],
    }:
    assert lib.assertMsg (isValidSkillName name)
      "Skill names must be lowercase alphanumeric words separated by single hyphens";
    assert lib.assertMsg (builtins.all lib.isDerivation runtimePackages)
      "skill-${name} runtime packages must be derivations";
    pkgs.runCommand "skill-${name}"
      {
        passthru = {
          inherit runtimeExecutables runtimePackages target;
        };
      }
      ''
        test -f ${lib.escapeShellArg "${target}/SKILL.md"}
        ${pkgs.gnugrep}/bin/grep -Fqx -- ${lib.escapeShellArg "name: ${name}"} ${lib.escapeShellArg "${target}/SKILL.md"}
        ${pkgs.gnugrep}/bin/grep -Eq '^description:' ${lib.escapeShellArg "${target}/SKILL.md"}
        ${lib.concatMapStringsSep "\n" (runtime: ''
          test -x ${lib.escapeShellArg "${runtime.package}/bin/${runtime.executable}"}
        '') runtimeExecutables}
        mkdir -p "$out"
        ln -s ${lib.escapeShellArg target} "$out/${name}"
      '';

  mkSkillTree =
    {
      pkgs,
      name,
      targets,
    }:
    pkgs.runCommand name { } ''
      mkdir -p "$out"
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (skillName: target: ''
          ln -s ${lib.escapeShellArg target} "$out/${skillName}"
        '') targets
      )}
    '';

  realizePiPackages =
    {
      extensions,
      pkgs,
    }:
    let
      packageEntries = lib.mapAttrsToList (
        name: extension:
        let
          package = extension.realization.package pkgs;
          packageVersion = package.version or null;
          declaredVersion = extension.realization.version;
        in
        assert lib.assertMsg (lib.isDerivation package) "extensions.${name} must realize to a Nix package";
        assert lib.assertMsg (packageVersion == null || packageVersion == declaredVersion)
          "extensions.${name} declared version ${declaredVersion} disagrees with package version ${toString packageVersion}";
        {
          inherit name package;
          inherit (extension.realization) packageId version;
          reference = "extensions.${name}";
          root = toString package;
        }
      ) (lib.filterAttrs (_: extension: extension.realization.type == "package") extensions);
      entriesById = lib.groupBy (entry: entry.packageId) packageEntries;
      packageIds = builtins.attrNames entriesById;
      validateIdentity =
        packageId:
        let
          entries = entriesById.${packageId};
          versions = lib.unique (map (entry: entry.version) entries);
          roots = lib.unique (map (entry: entry.root) entries);
          references = lib.concatStringsSep ", " (map (entry: entry.reference) entries);
        in
        assert lib.assertMsg (builtins.length versions == 1)
          "Pi package ${packageId} has conflicting versions ${lib.concatStringsSep ", " versions} from ${references}";
        assert lib.assertMsg (builtins.length roots == 1)
          "Pi package ${packageId}@${toString (builtins.head versions)} has conflicting package roots from ${references}";
        builtins.head entries;
      uniqueEntries = map validateIdentity packageIds;
    in
    {
      inherit packageEntries uniqueEntries;
      packages = map (entry: entry.package) uniqueEntries;
      settingsPackages = map (entry: entry.root) uniqueEntries;
    };

  realizeHerdrPlugins =
    {
      plugins,
      pkgs,
    }:
    lib.mapAttrs (
      name: plugin:
      let
        package = plugin.package pkgs;
        packageVersion = package.version or null;
        versionMatches = packageVersion == null || packageVersion == plugin.version;
        root =
          assert lib.assertMsg versionMatches
            "herdrPlugins.${name} source version ${plugin.version} disagrees with package version ${toString packageVersion}";
          pkgs.runCommand "herdr-plugin-${name}-${plugin.version}"
            {
              passthru = {
                inherit package;
                inherit (plugin)
                  executable
                  executablePath
                  minimumHerdrVersion
                  pluginId
                  source
                  version
                  ;
              };
            }
            ''
              set -euo pipefail
              test -x ${lib.escapeShellArg "${package}/bin/${plugin.executable}"}
              mkdir -p "$out/$(${pkgs.coreutils}/bin/dirname ${lib.escapeShellArg plugin.executablePath})"
              cp ${lib.escapeShellArg "${plugin.source}/herdr-plugin.toml"} "$out/herdr-plugin.toml"
              ln -s ${lib.escapeShellArg "${package}/bin/${plugin.executable}"} \
                "$out/${plugin.executablePath}"
              ${pkgs.gnugrep}/bin/grep -Fqx ${lib.escapeShellArg "id = \"${plugin.pluginId}\""} \
                "$out/herdr-plugin.toml"
              ${pkgs.gnugrep}/bin/grep -Fqx ${lib.escapeShellArg "version = \"${plugin.version}\""} \
                "$out/herdr-plugin.toml"
              ${pkgs.gnugrep}/bin/grep -Fqx \
                ${lib.escapeShellArg "min_herdr_version = \"${plugin.minimumHerdrVersion}\""} \
                "$out/herdr-plugin.toml"
            '';
      in
      {
        inherit package packageVersion root;
        inherit (plugin)
          executable
          executablePath
          pluginId
          source
          version
          ;
      }
    ) plugins;

  realizeSkills =
    {
      catalog,
      pkgs,
    }:
    let
      leafPathsFor =
        repositoryName:
        map (skill: skill.repositoryPath) (
          lib.filter (skill: skill.repository == repositoryName) (builtins.attrValues catalog.skills)
        );
      repositories = lib.mapAttrs (
        name: repository:
        mkRepositoryProjection {
          inherit pkgs name repository;
          leafPaths = leafPathsFor name;
          inherit (catalog) skills;
        }
      ) catalog.repositories;
      targets = lib.mapAttrs (
        name: skill:
        if skill.repository != null then
          repositories.${skill.repository} + "/${skill.repositoryPath}"
        else
          mkLocalSkillRoot {
            inherit pkgs name;
            inherit (skill) source;
          }
      ) catalog.skills;
      realizedLeaves = lib.mapAttrs (
        name: skill:
        let
          runtimeExecutables = map (runtime: {
            package = runtime.package pkgs;
            inherit (runtime) executable;
          }) skill.runtimeExecutables;
          runtimePackages = lib.unique (
            skill.runtimePackages pkgs ++ map (runtime: runtime.package) runtimeExecutables
          );
        in
        {
          inherit runtimeExecutables runtimePackages;
          target = targets.${name};
          package = mkSkillLink {
            inherit
              name
              pkgs
              runtimeExecutables
              runtimePackages
              ;
            target = targets.${name};
          };
        }
      ) catalog.skills;
    in
    {
      inherit realizedLeaves repositories targets;
      packages = lib.mapAttrs (_: leaf: leaf.package) realizedLeaves;
      runtimePackages = lib.unique (
        lib.concatMap (leaf: leaf.runtimePackages) (builtins.attrValues realizedLeaves)
      );
      tree = mkSkillTree {
        inherit pkgs;
        name = "dendritic-slop-agent-skills";
        inherit targets;
      };
    };

  realizeProfile =
    {
      catalog,
      pkgs,
      profileName,
      realizedExtensions,
      realizedHerdrPlugins,
      realizedSkills,
    }:
    let
      profile = catalog.profiles.${profileName};
      extensionPackages = builtins.listToAttrs (
        map (entry: lib.nameValuePair entry.name entry.package) realizedExtensions.packageEntries
      );
      artifactFor =
        kind: name:
        let
          resource = catalog.${kind}.${name};
        in
        if kind == "skills" then
          realizedSkills.packages.${name}
        else if kind == "mcps" then
          if resource.transport.type == "local" then
            resource.transport.package pkgs
          else
            pkgs.writeText "mcp-${name}.json" (
              builtins.toJSON {
                inherit (resource) lifecycle serverId;
                inherit (resource) transport;
              }
            )
        else if kind == "extensions" then
          if resource.realization.type == "package" then
            extensionPackages.${name}
          else
            resource.realization.source
        else if kind == "tools" then
          resource.package pkgs
        else
          realizedHerdrPlugins.${name}.root;
      resourceEntries = lib.concatMap (
        kind:
        map (name: {
          inherit kind name;
          artifact = artifactFor kind name;
        }) profile.members.${kind}
      ) resourceKinds;
      executableEntry = owner: package: executable: {
        inherit executable owner package;
        target = "${package}/bin/${executable}";
      };
      skillExecutables = lib.concatMap (
        name:
        map (
          runtime: executableEntry "skills.${name}" runtime.package runtime.executable
        ) realizedSkills.realizedLeaves.${name}.runtimeExecutables
      ) profile.members.skills;
      mcpExecutables = lib.concatMap (
        name:
        let
          resource = catalog.mcps.${name};
        in
        lib.optional (resource.transport.type == "local") (
          executableEntry "mcps.${name}" (resource.transport.package pkgs) resource.transport.executable
        )
      ) profile.members.mcps;
      toolExecutables = map (
        name:
        let
          resource = catalog.tools.${name};
        in
        executableEntry "tools.${name}" (resource.package pkgs) resource.executable
      ) profile.members.tools;
      pluginExecutables = map (
        name:
        let
          plugin = realizedHerdrPlugins.${name};
        in
        executableEntry "herdrPlugins.${name}" plugin.package plugin.executable
      ) profile.members.herdrPlugins;
      executableEntries = skillExecutables ++ mcpExecutables ++ toolExecutables ++ pluginExecutables;
      executableGroups = lib.groupBy (entry: entry.executable) executableEntries;
      executableCollisions = lib.filterAttrs (
        _: entries: builtins.length (lib.unique (map (entry: entry.target) entries)) > 1
      ) executableGroups;
      collisionNames = builtins.attrNames executableCollisions;
      uniqueExecutables = map (entries: builtins.head (lib.unique (map (entry: entry.target) entries))) (
        builtins.attrValues executableGroups
      );
      manifest = {
        profile = profileName;
        inherit (profile) targets;
        resources = profile.members;
        executables = builtins.attrNames executableGroups;
      };
    in
    assert lib.assertMsg (collisionNames == [ ]) (
      "Profile ${profileName} has executable collisions: "
      + lib.concatStringsSep ", " (
        map (
          executable:
          "${executable} from ${
            lib.concatStringsSep ", " (map (entry: entry.owner) executableCollisions.${executable})
          }"
        ) collisionNames
      )
    );
    pkgs.runCommand "all-${profileName}"
      {
        passthru = {
          inherit executableEntries manifest resourceEntries;
        };
      }
      ''
        set -euo pipefail
        mkdir -p "$out/bin" "$out/share/dendritic-slop/resources"
        ${lib.concatMapStringsSep "\n" (kind: ''
          mkdir -p "$out/share/dendritic-slop/resources/${kind}"
        '') resourceKinds}
        ${lib.concatMapStringsSep "\n" (entry: ''
          ln -s ${lib.escapeShellArg entry.artifact} \
            "$out/share/dendritic-slop/resources/${entry.kind}/${entry.name}"
        '') resourceEntries}
        ${lib.concatMapStringsSep "\n" (target: ''
          test -x ${lib.escapeShellArg target}
          ln -s ${lib.escapeShellArg target} "$out/bin/${builtins.baseNameOf target}"
        '') uniqueExecutables}
        cat > "$out/share/dendritic-slop/profile.json" <<'EOF'
        ${builtins.toJSON manifest}
        EOF
        test "$(${pkgs.findutils}/bin/find "$out/share/dendritic-slop/resources" -type l | wc -l | tr -d ' ')" \
          -eq ${toString (builtins.length resourceEntries)}
        test "$(${pkgs.findutils}/bin/find "$out/bin" -type l | wc -l | tr -d ' ')" \
          -eq ${toString (builtins.length uniqueExecutables)}
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
      mkLocalSkillRoot
      mkRepositoryProjection
      mkSkillLink
      mkSkillTree
      realizeHerdrPlugins
      realizePiPackages
      realizeProfile
      realizeSkills
      resolveResources
      resourceKinds
      targetNames
      ;
  };
}
