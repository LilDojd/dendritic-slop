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
      realizedSkills = config.dendriticSlopInternal.realized.skills pkgs;
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
      homeWithProfiles = mkHome {
        dendriticSlop = {
          profiles = {
            core.enable = true;
            python.enable = true;
          };
          skills = {
            brainstorming.enable = true;
            bro.enable = false;
            ty.enable = false;
          };
          targets.git.enable = false;
        };
      };
      homeWithTakeover = mkHome {
        dendriticSlop.migrations.globalSkills.takeOver = true;
      };
      homeWithWebAccess = mkHome {
        dendriticSlop.extensions.web-access.enable = true;
      };
      homeWithJjWorkspace = mkHome {
        dendriticSlop = {
          herdr.plugins.jj-workspace.enable = true;
          targets.herdr.enable = true;
        };
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
      managedHerdrAgentState =
        homeWithProfiles.config.home.file.".pi/agent/extensions/herdr-agent-state.ts";
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

      mkBridgeSystem =
        hostSelection: homeDefaults:
        let
          hostModule = {
            dendriticSlop = {
              enable = true;
              username = testUser;
            }
            // hostSelection;
            home-manager.users.${testUser} = {
              dendriticSlop = homeDefaults;
              home.stateVersion = "25.11";
            };
          };
        in
        if pkgs.stdenv.hostPlatform.isDarwin then
          inputs.nix-darwin.lib.darwinSystem {
            inherit system;
            modules = [
              inputs.home-manager.darwinModules.home-manager
              config.flake.modules.darwin.slop
              hostModule
              {
                system.stateVersion = 6;
                users.users.${testUser}.home = "/Users/${testUser}";
              }
            ];
          }
        else
          inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              inputs.home-manager.nixosModules.home-manager
              inputs.impermanence.nixosModules.impermanence
              config.flake.modules.nixos.slop
              hostModule
              {
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
                system.stateVersion = "25.11";
                users.users.${testUser}.isNormalUser = true;
              }
            ];
          };
      bridgeHome = host: host.config.home-manager.users.${testUser}.dendriticSlop;
      bridgeUnset = bridgeHome (
        mkBridgeSystem { } {
          profiles.core.enable = lib.mkDefault true;
          skills.ty.enable = lib.mkDefault true;
        }
      );
      bridgeTrue = bridgeHome (
        mkBridgeSystem
          {
            profiles.core.enable = true;
            skills.ty.enable = true;
          }
          {
            profiles.core.enable = lib.mkDefault false;
            skills.ty.enable = lib.mkDefault false;
          }
      );
      bridgeFalse = bridgeHome (
        mkBridgeSystem
          {
            profiles.core.enable = false;
            skills.ty.enable = false;
          }
          {
            profiles.core.enable = lib.mkDefault true;
            skills.ty.enable = lib.mkDefault true;
          }
      );

      allSkills = realizedSkills.tree;
      globalSkillsActivation = homeWithTakeover.config.home.activation.dendriticSlopGlobalSkillsTakeOver;
      globalSkillsTakeoverScript =
        homeWithTakeover.config.dendriticSlopInternal.globalSkills.takeoverScript;
    in
    {
      checks = {
        profile-selection =
          assert !(home.options.dendriticSlop ? autoEnable);
          assert !builtins.hasAttr "actionbook-rust" home.options.dendriticSlop.skills;
          assert !builtins.hasAttr "astral-python" home.options.dendriticSlop.skills;
          assert !builtins.hasAttr "superpowers" home.options.dendriticSlop.skills;
          assert
            builtins.attrNames home.config.dendriticSlop.profiles == [
              "core"
              "python"
              "rust"
              "superpowers"
              "web"
            ];
          assert lib.all (name: !home.config.dendriticSlop.skills.${name}.enable) (
            builtins.attrNames catalog.skills
          );
          assert homeWithProfiles.config.dendriticSlop.profiles.core.enable;
          assert homeWithProfiles.config.dendriticSlop.profiles.python.enable;
          assert !homeWithProfiles.config.dendriticSlop.skills.bro.enable;
          assert homeWithProfiles.config.dendriticSlop.skills.herdr.enable;
          assert homeWithProfiles.config.dendriticSlop.skills.jujutsu.enable;
          assert homeWithProfiles.config.dendriticSlop.skills.ruff.enable;
          assert !homeWithProfiles.config.dendriticSlop.skills.ty.enable;
          assert homeWithProfiles.config.dendriticSlop.skills.uv.enable;
          assert homeWithProfiles.config.dendriticSlop.skills.brainstorming.enable;
          assert !homeWithProfiles.config.dendriticSlop.targets.git.enable;
          assert homeWithProfiles.config.dendriticSlop.targets.herdr.enable;
          assert homeWithProfiles.config.dendriticSlop.targets.pi.enable;
          assert homeWithProfiles.config.dendriticSlop.targets.rules.enable;
          assert bridgeUnset.profiles.core.enable && bridgeUnset.skills.ty.enable;
          assert bridgeTrue.profiles.core.enable && bridgeTrue.skills.ty.enable;
          assert !bridgeFalse.profiles.core.enable && !bridgeFalse.skills.ty.enable;
          pkgs.runCommand "profile-selection-check" { } ''
            touch "$out"
          '';
        global-skills-activation =
          assert builtins.elem "checkLinkTargets" globalSkillsActivation.before;
          pkgs.runCommand "global-skills-activation-check" { } ''
            set -euo pipefail
            takeover=${globalSkillsTakeoverScript}

            expect_stop() {
              local point="$1"
              local home="$2"
              shift 2
              set +e
              HOME="$home" DENDRITIC_SLOP_TEST_STOP_AFTER="$point" "$@" "$takeover"
              status=$?
              set -e
              test "$status" -eq 75
            }

            expect_failure() {
              local home="$1"
              shift
              if HOME="$home" "$@" "$takeover"; then
                echo "expected takeover failure for $home" >&2
                exit 1
              fi
            }

            expect_publication_race_refusal() {
              local mode="$1"
              local point="$2"
              local home="$3"
              local ready="$home/race-ready"
              local release="$home/race-release"
              local destination="$home/.local/state/dendritic-slop/global-skills/backups/.skill-lock.json"
              local pid status attempt

              mkdir -p "$home/.agents"
              printf transaction-source > "$home/.agents/.skill-lock.json"
              if test "$mode" = exdev; then
                HOME="$home" \
                  DENDRITIC_SLOP_TEST_FORCE_EXDEV=skill-lock \
                  DENDRITIC_SLOP_TEST_PAUSE_AFTER_READY="$point" \
                  DENDRITIC_SLOP_TEST_READY_SIGNAL="$ready" \
                  DENDRITIC_SLOP_TEST_RELEASE_SIGNAL="$release" \
                  "$takeover" &
              else
                HOME="$home" \
                  DENDRITIC_SLOP_TEST_PAUSE_AFTER_READY="$point" \
                  DENDRITIC_SLOP_TEST_READY_SIGNAL="$ready" \
                  DENDRITIC_SLOP_TEST_RELEASE_SIGNAL="$release" \
                  "$takeover" &
              fi
              pid=$!

              for attempt in {1..1000}; do
                test ! -e "$ready" || break
                sleep 0.01
              done
              if test ! -e "$ready"; then
                kill "$pid" 2>/dev/null || true
                wait "$pid" 2>/dev/null || true
                echo "takeover did not reach $point" >&2
                exit 1
              fi

              printf post-ready-collision > "$destination"
              touch "$release"
              set +e
              wait "$pid"
              status=$?
              set -e

              test "$status" -ne 0
              test "$(cat "$destination")" = post-ready-collision
              test "$(cat "$home/.agents/.skill-lock.json")" = transaction-source
            }

            fake="$TMPDIR/fake-homes"
            mkdir -p "$fake"

            # No prior directory: record both absent steps and complete.
            home="$fake/absent"
            mkdir -p "$home"
            HOME="$home" "$takeover"
            test -e "$home/.local/state/dendritic-slop/global-skills/completed"
            test ! -e "$home/.local/state/dendritic-slop/global-skills/backups/skills"

            # A prior managed symlink is backed up as a symlink, then a store
            # symlink is accepted on an idempotent completed rerun.
            home="$fake/managed-link"
            mkdir -p "$home/.agents"
            ln -s ${allSkills} "$home/.agents/skills"
            HOME="$home" "$takeover"
            test -L "$home/.local/state/dendritic-slop/global-skills/backups/skills"
            test "$(readlink "$home/.local/state/dendritic-slop/global-skills/backups/skills")" = ${allSkills}
            ln -s ${allSkills} "$home/.agents/skills"
            HOME="$home" "$takeover"

            # Known and unknown unmanaged entries, plus the old lock, survive
            # together in the persistent transaction backup.
            home="$fake/unmanaged"
            mkdir -p "$home/.agents/skills/dioxus" "$home/.agents/skills/unknown"
            printf known > "$home/.agents/skills/dioxus/SKILL.md"
            printf unknown > "$home/.agents/skills/unknown/custom.txt"
            printf lock > "$home/.agents/.skill-lock.json"
            HOME="$home" "$takeover"
            backup="$home/.local/state/dendritic-slop/global-skills/backups"
            test "$(cat "$backup/skills/dioxus/SKILL.md")" = known
            test "$(cat "$backup/skills/unknown/custom.txt")" = unknown
            test "$(cat "$backup/.skill-lock.json")" = lock
            test ! -e "$home/.agents/skills"
            test ! -e "$home/.agents/.skill-lock.json"

            # Existing backup destinations are never overwritten.
            home="$fake/existing-backup"
            mkdir -p "$home/.agents/skills" "$home/.local/state/dendritic-slop/global-skills/backups/skills"
            printf source > "$home/.agents/skills/source"
            printf backup > "$home/.local/state/dendritic-slop/global-skills/backups/skills/existing"
            expect_failure "$home" env
            test "$(cat "$home/.agents/skills/source")" = source
            test "$(cat "$home/.local/state/dendritic-slop/global-skills/backups/skills/existing")" = backup

            # A destination created after the ready marker wins the race and
            # survives atomic no-replace publication on both transfer paths.
            expect_publication_race_refusal \
              same-filesystem skill-lock-rename-ready "$fake/same-filesystem-publication-race"
            expect_publication_race_refusal \
              exdev skill-lock-copy-ready "$fake/exdev-publication-race"

            # Resume directly from a prepared journal.
            home="$fake/prepared-resume"
            mkdir -p "$home/.agents/skills"
            printf prepared > "$home/.agents/skills/value"
            expect_stop prepared "$home" env
            test -e "$home/.local/state/dendritic-slop/global-skills/journal/inventory/skills"
            mkdir "$home/.local/state/dendritic-slop/global-skills/lock"
            HOME="$home" "$takeover"
            test "$(cat "$home/.local/state/dendritic-slop/global-skills/backups/skills/value")" = prepared

            # Resume a same-filesystem rename interrupted before its done marker.
            home="$fake/rename-resume"
            mkdir -p "$home/.agents/skills"
            printf renamed > "$home/.agents/skills/value"
            expect_stop skills-transferred "$home" env
            test ! -e "$home/.agents/skills"
            test ! -e "$home/.local/state/dendritic-slop/global-skills/journal/steps/skills.done"
            HOME="$home" "$takeover"
            test -e "$home/.local/state/dendritic-slop/global-skills/journal/steps/skills.done"

            # A completed path step will not delete content recreated at its source.
            home="$fake/interrupted-collision"
            mkdir -p "$home/.agents/skills"
            printf original > "$home/.agents/skills/value"
            expect_stop skills "$home" env
            mkdir -p "$home/.agents/skills"
            printf collision > "$home/.agents/skills/value"
            expect_failure "$home" env
            test "$(cat "$home/.agents/skills/value")" = collision
            test "$(cat "$home/.local/state/dendritic-slop/global-skills/backups/skills/value")" = original

            # Exercise the EXDEV branch for both a directory and regular file.
            home="$fake/exdev"
            mkdir -p "$home/.agents/skills"
            printf copied > "$home/.agents/skills/value"
            printf lock > "$home/.agents/.skill-lock.json"
            expect_stop skills-copy-ready "$home" env DENDRITIC_SLOP_TEST_FORCE_EXDEV=all
            HOME="$home" DENDRITIC_SLOP_TEST_FORCE_EXDEV=all "$takeover"
            test "$(cat "$home/.local/state/dendritic-slop/global-skills/backups/skills/value")" = copied
            test "$(cat "$home/.local/state/dendritic-slop/global-skills/backups/.skill-lock.json")" = lock
            test -e "$home/.local/state/dendritic-slop/global-skills/journal/steps/skills.cross-filesystem"
            test -e "$home/.local/state/dendritic-slop/global-skills/journal/steps/skill-lock.cross-filesystem"

            # A collision after completion is reported and preserved.
            home="$fake/completed-collision"
            mkdir -p "$home"
            HOME="$home" "$takeover"
            mkdir -p "$home/.agents/skills"
            printf post > "$home/.agents/skills/value"
            expect_failure "$home" env
            test "$(cat "$home/.agents/skills/value")" = post

            # The obsolete lock source is also forbidden after completion.
            home="$fake/completed-lock-collision"
            mkdir -p "$home"
            HOME="$home" "$takeover"
            printf new-manager-state > "$home/.agents/.skill-lock.json"
            expect_failure "$home" env
            test "$(cat "$home/.agents/.skill-lock.json")" = new-manager-state

            touch "$out"
          '';
        skill-projections =
          let
            actionbookRepository = catalog.repositories.actionbook-rust;
            astralRepository = catalog.repositories.astral-python;
            leonardoRepository = catalog.repositories.leonardomso-rust-skills;
            superpowersRepository = catalog.repositories.superpowers;
            actionbookUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (actionbookRepository.source + "/skills")
              )
            );
            astralUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (astralRepository.source + "/plugins/astral/skills")
              )
            );
            superpowersUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (superpowersRepository.source + "/skills")
              )
            );
            reviewedEntrypoints = [
              ".pi/extensions/superpowers.ts"
              "skills/brainstorming/scripts/helper.js"
              "skills/brainstorming/scripts/server.cjs"
              "skills/brainstorming/scripts/start-server.sh"
              "skills/brainstorming/scripts/stop-server.sh"
              "skills/subagent-driven-development/scripts/review-package"
              "skills/subagent-driven-development/scripts/sdd-workspace"
              "skills/subagent-driven-development/scripts/task-brief"
              "skills/systematic-debugging/find-polluter.sh"
            ];
            intentionallyOmittedEntrypoints = [
              "skills/writing-skills/render-graphs.js"
            ];
            executableEntrypoints = map (entrypoint: entrypoint.path) (
              lib.filter (entrypoint: entrypoint.type == "executable") superpowersRepository.entrypoints
            );
            actionbookProjection = realizedSkills.repositories.actionbook-rust;
            astralProjection = realizedSkills.repositories.astral-python;
            leonardoProjection = realizedSkills.repositories.leonardomso-rust-skills;
            superpowersProjection = realizedSkills.repositories.superpowers;
          in
          assert
            lib.sort builtins.lessThan (
              actionbookRepository.exportedLeaves ++ actionbookRepository.ignoredLeaves
            ) == actionbookUpstreamLeaves;
          assert
            actionbookRepository.ignoredLeaves == [
              "core-actionbook"
              "core-agent-browser"
              "core-dynamic-skills"
              "core-fix-skill-docs"
            ];
          assert lib.sort builtins.lessThan astralRepository.exportedLeaves == astralUpstreamLeaves;
          assert astralRepository.ignoredLeaves == [ ];
          assert lib.sort builtins.lessThan superpowersRepository.exportedLeaves == superpowersUpstreamLeaves;
          assert superpowersRepository.ignoredLeaves == [ ];
          assert leonardoRepository.exportedLeaves == [ "rust-skills" ];
          assert map (entrypoint: entrypoint.path) superpowersRepository.entrypoints == reviewedEntrypoints;
          assert superpowersRepository.ignoredEntrypoints == intentionallyOmittedEntrypoints;
          assert lib.all (
            entrypoint:
            entrypoint.owner != null
            && (
              (entrypoint.type == "executable" && entrypoint.interpreter == null)
              || (entrypoint.type == "interpreter" && entrypoint.interpreter != null)
            )
          ) superpowersRepository.entrypoints;
          assert builtins.all builtins.pathExists (
            actionbookRepository.licenseEvidence
            ++ astralRepository.licenseEvidence
            ++ leonardoRepository.licenseEvidence
            ++ superpowersRepository.licenseEvidence
          );
          pkgs.runCommand "skill-projections-check"
            {
              leafPackages = builtins.attrValues realizedSkills.packages;
            }
            ''
              set -euo pipefail

              test "$(${pkgs.findutils}/bin/find ${allSkills} -mindepth 1 -maxdepth 1 -type l | wc -l | tr -d ' ')" -eq ${toString (builtins.length (builtins.attrNames catalog.skills))}
              ${lib.concatMapStringsSep "\n" (name: ''
                test "$(readlink ${allSkills}/${name})" = ${
                  lib.escapeShellArg (toString realizedSkills.targets.${name})
                }
                test -L ${realizedSkills.packages.${name}}/${name}
                test -f ${allSkills}/${name}/SKILL.md
                ${pkgs.gnugrep}/bin/grep -Fqx ${lib.escapeShellArg "name: ${name}"} ${allSkills}/${name}/SKILL.md
                ${pkgs.gnugrep}/bin/grep -Eq '^description:' ${allSkills}/${name}/SKILL.md
              '') (builtins.attrNames catalog.skills)}

              test -f ${allSkills}/rust-learner/../../agents/crate-researcher.md
              test -f ${allSkills}/rust-learner/../../agents/rust-changelog.md
              test -f ${allSkills}/rust-daily/../../agents/rust-daily-reporter.md
              test -f ${allSkills}/meta-cognition-parallel/../../agents/layer1-analyzer.md
              test -f ${allSkills}/rust-router/patterns/negotiation.md
              test -f ${allSkills}/unsafe-checker/rules/ffi-01-no-string-direct.md

              test -f ${allSkills}/writing-skills/../using-superpowers/references/codex-tools.md
              test -f ${allSkills}/subagent-driven-development/../requesting-code-review/code-reviewer.md
              test -f ${allSkills}/executing-plans/../using-superpowers/references/pi-tools.md
              test -f ${allSkills}/brainstorming/scripts/frame-template.html

              # Omission smoke test through the final leaf link: the helper and its
              # immutable-write workflow must both be absent from the installed skill.
              test ! -e ${allSkills}/writing-skills/render-graphs.js
              ! ${pkgs.gnugrep}/bin/grep -Fq 'render-graphs.js' ${allSkills}/writing-skills/SKILL.md
              ${pkgs.gnugrep}/bin/grep -Fq 'omitted from immutable installations' ${allSkills}/writing-skills/SKILL.md

              test -f ${superpowersRepository.source}/skills/writing-skills/render-graphs.js
              test ! -e ${superpowersProjection}/skills/writing-skills/render-graphs.js
              test -f ${superpowersProjection}/package.json
              test -f ${superpowersProjection}/.pi/extensions/superpowers.ts
              ${pkgs.gnugrep}/bin/grep -Fq 'resources_discover' ${superpowersProjection}/.pi/extensions/superpowers.ts

              test -f ${actionbookProjection}/metadata.json
              ${pkgs.gnugrep}/bin/grep -Eq '"license"[[:space:]]*:[[:space:]]*"MIT"' ${actionbookProjection}/metadata.json
              ${pkgs.gnugrep}/bin/grep -Fq 'MIT License' ${actionbookProjection}/README.md
              test -f ${astralProjection}/LICENSE-APACHE
              test -f ${astralProjection}/LICENSE-MIT
              test -f ${leonardoProjection}/LICENSE
              test -f ${superpowersProjection}/LICENSE

              ${lib.concatMapStringsSep "\n" (path: ''
                test -x ${superpowersProjection}/${path}
                shebang=$(head -n 1 ${superpowersProjection}/${path})
                if ! printf '%s\n' "$shebang" | ${pkgs.gnugrep}/bin/grep -Eq '^#! ?/nix/store/'; then
                  echo "unpatched shebang: ${path}: $shebang" >&2
                  exit 1
                fi
              '') executableEntrypoints}
              ${lib.concatMapStringsSep "\n" (entrypoint: ''
                test -f ${superpowersProjection}/${entrypoint.path}
              '') (lib.filter (entrypoint: entrypoint.type == "interpreter") superpowersRepository.entrypoints)}

              brainstorm_wrapper=${superpowersProjection}/skills/brainstorming/scripts/start-server.sh
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.nodejs_24)} "$brainstorm_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gitMinimal)} "$brainstorm_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.graphviz)} "$brainstorm_wrapper"

              subagent_wrapper=${superpowersProjection}/skills/subagent-driven-development/scripts/review-package
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gawk)} "$subagent_wrapper"
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gitMinimal)} "$subagent_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.nodejs_24)} "$subagent_wrapper"

              debugging_wrapper=${superpowersProjection}/skills/systematic-debugging/find-polluter.sh
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.findutils)} "$debugging_wrapper"
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.nodejs_24)} "$debugging_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gitMinimal)} "$debugging_wrapper"

              test "$(${pkgs.findutils}/bin/find ${actionbookProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'README.md _meta agents metadata.json skills '
              test "$(${pkgs.findutils}/bin/find ${astralProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'LICENSE-APACHE LICENSE-MIT plugins '
              test "$(${pkgs.findutils}/bin/find ${leonardoProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'LICENSE SKILL.md rules '
              test "$(${pkgs.findutils}/bin/find ${superpowersProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = '.pi LICENSE package.json skills '

              for projection in ${actionbookProjection} ${astralProjection} ${leonardoProjection} ${superpowersProjection}; do
                test ! -e "$projection/setup.sh"
                test ! -e "$projection/hooks"
                test ! -e "$projection/.claude"
                test ! -e "$projection/.github"
              done
              touch "$out"
            '';
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
          assert catalog.skills.coding-guidelines.defaultEnable;
          assert catalog.skills.ruff.defaultEnable;
          assert !catalog.skills.brainstorming.defaultEnable;
          assert (builtins.head catalog.skills.jujutsu.runtimeExecutables).package pkgs == pkgs.jujutsu;
          assert
            catalog.extensions.ask-user.defaultEnable == legacyResources.extensions.ask-user.defaultEnable;
          assert
            catalog.extensions.web-access.defaultEnable == legacyResources.extensions.web-access.defaultEnable;
          pkgs.runCommand "registry-schema-check" { } ''
            touch "$out"
          '';
        all-skills = allSkills;
        home-manager-module =
          assert home.config.programs.pi.coding-agent.extensions == [ ];
          assert home.config.programs.pi.coding-agent.skills == [ ];
          assert lib.all (
            name: !home.config.dendriticSlop.skills.${name}.enable
          ) catalog.profiles.superpowers.members.skills;
          assert managedHerdrAgentState.source == herdrAgentStateResource.source;
          assert managedHerdrAgentState.force;
          assert !managedSkills.force;
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
        nixos-module =
          assert builtins.elem ".pi/agent" (
            map (
              entry: entry.directory
            ) nixos.config.environment.persistence."/persistent".users.${testUser}.directories
          );
          assert builtins.elem ".local/state/dendritic-slop" (
            map (
              entry: entry.directory
            ) nixos.config.environment.persistence."/persistent".users.${testUser}.directories
          );
          nixos.config.system.build.toplevel;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        darwin-module = darwin.system;
      };

      formatter = pkgs.nixfmt-tree;
    };
}
