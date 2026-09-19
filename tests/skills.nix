{
  allSkills,
  catalog,
  lib,
  pkgs,
  realizedSkills,
  ...
}:
{
  skill-projections =
    let
      actionbookRepository = catalog.repositories.actionbook-rust;
      astralRepository = catalog.repositories.astral-python;
      leonardoRepository = catalog.repositories.leonardomso-rust-skills;
      ponytailRepository = catalog.repositories.ponytail;
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
      ponytailUpstreamLeaves = builtins.attrNames (
        lib.filterAttrs (_: type: type == "directory") (
          builtins.readDir (ponytailRepository.source + "/skills")
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
      ponytailProjection = realizedSkills.repositories.ponytail;
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
    assert lib.sort builtins.lessThan ponytailRepository.exportedLeaves == ponytailUpstreamLeaves;
    assert ponytailRepository.ignoredLeaves == [ ];
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
      ++ ponytailRepository.licenseEvidence
      ++ superpowersRepository.licenseEvidence
    );
    pkgs.runCommand "skill-projections-check"
      {
        leafPackages = builtins.attrValues realizedSkills.packages;
      }
      ''
        set -euo pipefail
        export LC_ALL=C

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
        ! ${pkgs.gnugrep}/bin/grep -Fq 'resources_discover' ${superpowersProjection}/.pi/extensions/superpowers.ts
        ${pkgs.gnugrep}/bin/grep -Fq '## Pi tool mapping' ${superpowersProjection}/.pi/extensions/superpowers.ts

        test -f ${actionbookProjection}/metadata.json
        ${pkgs.gnugrep}/bin/grep -Eq '"license"[[:space:]]*:[[:space:]]*"MIT"' ${actionbookProjection}/metadata.json
        ${pkgs.gnugrep}/bin/grep -Fq 'MIT License' ${actionbookProjection}/README.md
        test -f ${astralProjection}/LICENSE-APACHE
        test -f ${astralProjection}/LICENSE-MIT
        test -f ${leonardoProjection}/LICENSE
        test -f ${ponytailProjection}/LICENSE
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
  all-skills = allSkills;
}
