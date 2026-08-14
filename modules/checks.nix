{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      testUser = "slop-test";
      catalog = config.dendriticSlopInternal.catalog;
      legacyResources = config.dendriticSlopInternal.resources;
      catalogType = config.dendriticSlopInternal.resourceSchema.catalogType;
      inherit (config.flake.lib) evalResourceSelection resolveResources;

      resolve =
        catalog': requested:
        resolveResources {
          catalog = catalog';
          selection = evalResourceSelection {
            catalog = catalog';
            selection = requested;
          };
          inherit pkgs;
        };
      tryResolve =
        catalog': requested:
        builtins.tryEval (
          let
            resolved = resolve catalog' requested;
          in
          builtins.deepSeq resolved resolved
        );

      tryCatalog =
        value:
        builtins.tryEval (
          let
            evaluated =
              (lib.evalModules {
                modules = [
                  {
                    options.fixture = lib.mkOption { type = catalogType; };
                    config.fixture = value;
                  }
                ];
              }).config.fixture;
          in
          builtins.deepSeq evaluated evaluated
        );

      catalogEvaluation = builtins.tryEval (builtins.deepSeq catalog catalog);
      invalidMcpVariant = tryCatalog {
        mcps.invalid = {
          title = "Invalid MCP";
          description = "Schema fixture with mixed remote and local fields.";
          transport = {
            type = "remote";
            url = "https://example.invalid/mcp";
            executable = "invalid";
          };
        };
      };
      invalidExtensionVariant = tryCatalog {
        extensions.invalid = {
          title = "Invalid extension";
          description = "Schema fixture with mixed path and package fields.";
          realization = {
            type = "path";
            source = ./checks.nix;
            destination = ".pi/agent/extensions/invalid.ts";
            package = _: pkgs.hello;
          };
        };
      };

      absentSelection = evalResourceSelection { inherit catalog; };
      nullableSelection = evalResourceSelection {
        inherit catalog;
        selection = {
          skills.bro = null;
          targets.herdr = null;
        };
      };
      explicitFalseSelection = evalResourceSelection {
        inherit catalog;
        selection = {
          skills.bro = false;
          targets.herdr = false;
        };
      };
      profileDefaultSelection = evalResourceSelection {
        inherit catalog;
        selection.profiles.core = true;
      };
      explicitTrueSelection = evalResourceSelection {
        inherit catalog;
        selection = {
          skills.bro = true;
          targets.herdr = true;
        };
      };

      profileOnly = tryResolve catalog { profiles.core = true; };
      standaloneLeaf = tryResolve catalog { skills.bro = true; };
      realSkillPackages = tryResolve catalog { skills.coding-guidelines = true; };
      profileWithDisable = tryResolve catalog {
        profiles.core = true;
        skills.bro = false;
      };
      profileUnion = tryResolve catalog {
        profiles.core = true;
        profiles.web = true;
      };
      disabledRequirement = tryResolve catalog {
        profiles.core = true;
        targets.herdr = false;
      };
      duplicateCatalog = catalog // {
        skills = catalog.skills // {
          duplicate-bro = catalog.skills.bro // {
            name = "duplicate-bro";
            profiles = [ ];
          };
        };
      };
      duplicateExposedName = tryResolve duplicateCatalog {
        skills = {
          bro = true;
          duplicate-bro = true;
        };
      };
      unsupportedSystem = if system == "x86_64-linux" then "aarch64-darwin" else "x86_64-linux";
      unsupportedCatalog = catalog // {
        skills = catalog.skills // {
          unsupported-runtime = catalog.skills.coding-guidelines // {
            name = "unsupported-runtime";
            exposedName = "unsupported-runtime";
            profiles = [ ];
            runtimePackages = _: [
              (pkgs.hello.overrideAttrs (_: {
                meta.platforms = [ unsupportedSystem ];
              }))
            ];
          };
        };
      };
      unsupportedPackage = tryResolve unsupportedCatalog { skills.unsupported-runtime = true; };

      packagePaths = map (package: package.drvPath);
      sourceActionbookPackages = legacyResources.skills.actionbook-rust.runtimeInputs pkgs;
      typedActionbookPackages = catalog.skills.coding-guidelines.runtimePackages pkgs;
      sourceAstralPackages = legacyResources.skills.astral-python.runtimeInputs pkgs;
      typedAstralPackages = catalog.skills.ruff.runtimePackages pkgs;

      mkHome =
        extraModule:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            config.flake.modules.homeManager.slop
            {
              dendriticSlop.enable = true;
              home = {
                username = testUser;
                homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${testUser}" else "/home/${testUser}";
                stateVersion = "25.11";
              };
            }
            extraModule
          ];
        };

      home = mkHome { };
      homeWithWebAccess = mkHome {
        dendriticSlop.extensions.web-access.enable = true;
      };
      homeWithJjWorkspace = mkHome {
        dendriticSlop.herdr.plugins.jj-workspace.enable = true;
      };
      jjWorkspaceResource = config.dendriticSlopInternal.resources.herdrPlugins.jj-workspace;
      jjWorkspacePackage = jjWorkspaceResource.package pkgs;
      jjWorkspaceRoot = jjWorkspaceResource.pluginRoot pkgs;
      defaultJjWorkspaceActivation =
        home.config.home.activation."dendriticSlopHerdrPlugin-jj-workspace".data;
      jjWorkspaceActivation =
        homeWithJjWorkspace.config.home.activation."dendriticSlopHerdrPlugin-jj-workspace".data;
      jjWorkspaceManifest = pkgs.runCommand "herdr-plugin-jj-workspace-manifest-check" { } ''
        test -x ${jjWorkspaceRoot}/target/release/jj-workspace
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "nathanflurry.jj-workspace"' ${jjWorkspaceRoot}/herdr-plugin.toml
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "new"' ${jjWorkspaceRoot}/herdr-plugin.toml
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "new-tab"' ${jjWorkspaceRoot}/herdr-plugin.toml
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "remove"' ${jjWorkspaceRoot}/herdr-plugin.toml
        touch "$out"
      '';
      herdrAgentStateResource = config.dendriticSlopInternal.resources.extensions.herdr-agent-state;
      managedHerdrAgentState = home.config.home.file.".pi/agent/extensions/herdr-agent-state.ts";
      managedSkills = home.config.home.file.".agents/skills";
      webAccessPackage = config.dendriticSlopInternal.resources.extensions.web-access.package;
      defaultPackages = home.config.programs.pi.coding-agent.settings.packages;
      optedInPackages = homeWithWebAccess.config.programs.pi.coding-agent.settings.packages;

      nixos = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.impermanence.nixosModules.impermanence
          config.flake.modules.nixos.slop
          {
            dendriticSlop = {
              enable = true;
              username = testUser;
            };
            boot.loader.grub.devices = [ "nodev" ];
            fileSystems = {
              "/" = {
                device = "none";
                fsType = "tmpfs";
              };
              "/persistent" = {
                device = "none";
                fsType = "tmpfs";
                neededForBoot = true;
              };
            };
            home-manager.users.${testUser}.home.stateVersion = "25.11";
            system.stateVersion = "25.11";
            users.users.${testUser}.isNormalUser = true;
          }
        ];
      };

      darwin = inputs.nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          inputs.home-manager.darwinModules.home-manager
          config.flake.modules.darwin.slop
          {
            dendriticSlop = {
              enable = true;
              username = testUser;
            };
            home-manager.users.${testUser}.home.stateVersion = "25.11";
            system.stateVersion = 6;
            users.users.${testUser}.home = "/Users/${testUser}";
          }
        ];
      };

      allSkills = pkgs.symlinkJoin {
        name = "all-dendritic-slop-skills";
        paths = lib.mapAttrsToList (
          name: resource:
          config.flake.lib.mkSkill {
            inherit pkgs name;
            inherit (resource)
              collection
              extraFiles
              members
              source
              ;
            runtimeInputs = resource.runtimeInputs pkgs;
          }
        ) config.dendriticSlopInternal.resources.skills;
      };
    in
    {
      checks = {
        registry-schema =
          assert catalogEvaluation.success;
          assert !invalidMcpVariant.success;
          assert !invalidExtensionVariant.success;
          assert absentSelection.overrides.skills.bro == null;
          assert absentSelection.overrides.targets.herdr == null;
          assert !absentSelection.effective.skills.bro;
          assert !absentSelection.effective.targets.herdr;
          assert nullableSelection.overrides.skills.bro == null;
          assert nullableSelection.overrides.targets.herdr == null;
          assert !nullableSelection.effective.skills.bro;
          assert !nullableSelection.effective.targets.herdr;
          assert explicitFalseSelection.overrides.skills.bro == false;
          assert explicitFalseSelection.overrides.targets.herdr == false;
          assert !explicitFalseSelection.effective.skills.bro;
          assert !explicitFalseSelection.effective.targets.herdr;
          assert profileDefaultSelection.overrides.skills.bro == null;
          assert profileDefaultSelection.overrides.targets.herdr == null;
          assert profileDefaultSelection.effective.skills.bro;
          assert profileDefaultSelection.effective.targets.herdr;
          assert explicitTrueSelection.overrides.skills.bro == true;
          assert explicitTrueSelection.overrides.targets.herdr == true;
          assert explicitTrueSelection.effective.skills.bro;
          assert explicitTrueSelection.effective.targets.herdr;
          assert profileOnly.success;
          assert profileOnly.value.skills ? bro;
          assert builtins.elem "herdr" profileOnly.value.targets;
          assert standaloneLeaf.success;
          assert standaloneLeaf.value.skills ? bro;
          assert realSkillPackages.success;
          assert realSkillPackages.value.skills ? coding-guidelines;
          assert profileWithDisable.success;
          assert profileWithDisable.value.selection.overrides.skills.bro == false;
          assert !(profileWithDisable.value.skills ? bro);
          assert profileUnion.success;
          assert profileUnion.value.extensions ? web-access;
          assert !disabledRequirement.success;
          assert !duplicateExposedName.success;
          assert !unsupportedPackage.success;
          assert catalog.skills.bro.defaultEnable == legacyResources.skills.bro.defaultEnable;
          assert
            catalog.skills.coding-guidelines.defaultEnable
            == legacyResources.skills.actionbook-rust.defaultEnable;
          assert catalog.skills.ruff.defaultEnable == legacyResources.skills.astral-python.defaultEnable;
          assert
            catalog.skills.brainstorming.defaultEnable == legacyResources.skills.superpowers.defaultEnable;
          assert
            catalog.extensions.ask-user.defaultEnable == legacyResources.extensions.ask-user.defaultEnable;
          assert
            catalog.extensions.web-access.defaultEnable == legacyResources.extensions.web-access.defaultEnable;
          assert packagePaths typedActionbookPackages == packagePaths sourceActionbookPackages;
          assert packagePaths typedAstralPackages == packagePaths sourceAstralPackages;
          assert typedActionbookPackages != [ ];
          assert typedAstralPackages != [ ];
          pkgs.runCommand "registry-schema-check" { } ''
            touch "$out"
          '';
        all-skills = allSkills;
        home-manager-module =
          assert home.config.programs.pi.coding-agent.extensions == [ ];
          assert home.config.programs.pi.coding-agent.skills == [ ];
          assert !home.config.dendriticSlop.skills.superpowers.enable;
          assert managedHerdrAgentState.source == herdrAgentStateResource.source;
          assert managedHerdrAgentState.force;
          assert managedSkills.force;
          assert !builtins.elem webAccessPackage defaultPackages;
          home.activationPackage;
        web-access-opt-in =
          assert builtins.elem webAccessPackage optedInPackages;
          homeWithWebAccess.activationPackage;
        herdr-plugin-jj-workspace-package = jjWorkspacePackage;
        herdr-plugin-jj-workspace-root = jjWorkspaceRoot;
        herdr-plugin-jj-workspace-manifest = jjWorkspaceManifest;
        herdr-plugin-jj-workspace-opt-in =
          assert !home.config.dendriticSlop.herdr.plugins.jj-workspace.enable;
          assert homeWithJjWorkspace.config.dendriticSlop.herdr.plugins.jj-workspace.enable;
          assert builtins.isString defaultJjWorkspaceActivation && defaultJjWorkspaceActivation != "";
          assert builtins.isString jjWorkspaceActivation && jjWorkspaceActivation != "";
          assert
            map (binding: binding.key) jjWorkspaceResource.keybindings == [
              "prefix+a"
              "prefix+shift+a"
              "prefix+d"
            ];
          assert
            map (binding: binding.command) jjWorkspaceResource.keybindings == [
              "nathanflurry.jj-workspace.new-tab"
              "nathanflurry.jj-workspace.new"
              "nathanflurry.jj-workspace.remove"
            ];
          assert defaultJjWorkspaceActivation != jjWorkspaceActivation;
          homeWithJjWorkspace.activationPackage;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        nixos-module = nixos.config.system.build.toplevel;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        darwin-module = darwin.system;
      };

      formatter = pkgs.nixfmt-tree;
      packages.all-skills = allSkills;
    };
}
