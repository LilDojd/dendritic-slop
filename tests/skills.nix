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
      actionbookProjection = realizedSkills.repositories.actionbook-rust;
      astralProjection = realizedSkills.repositories.astral-python;
      leonardoProjection = realizedSkills.repositories.leonardomso-rust-skills;
      ponytailProjection = realizedSkills.repositories.ponytail;
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
    assert leonardoRepository.exportedLeaves == [ "rust-skills" ];
    assert lib.sort builtins.lessThan ponytailRepository.exportedLeaves == ponytailUpstreamLeaves;
    assert ponytailRepository.ignoredLeaves == [ ];
    assert builtins.all builtins.pathExists (
      actionbookRepository.licenseEvidence
      ++ astralRepository.licenseEvidence
      ++ leonardoRepository.licenseEvidence
      ++ ponytailRepository.licenseEvidence
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

        test -f ${actionbookProjection}/metadata.json
        ${pkgs.gnugrep}/bin/grep -Eq '"license"[[:space:]]*:[[:space:]]*"MIT"' ${actionbookProjection}/metadata.json
        ${pkgs.gnugrep}/bin/grep -Fq 'MIT License' ${actionbookProjection}/README.md
        test -f ${astralProjection}/LICENSE-APACHE
        test -f ${astralProjection}/LICENSE-MIT
        test -f ${leonardoProjection}/LICENSE
        test -f ${ponytailProjection}/LICENSE

        test "$(${pkgs.findutils}/bin/find ${actionbookProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'README.md _meta agents metadata.json skills '
        test "$(${pkgs.findutils}/bin/find ${astralProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'LICENSE-APACHE LICENSE-MIT plugins '
        test "$(${pkgs.findutils}/bin/find ${leonardoProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'LICENSE SKILL.md rules '

        for projection in ${actionbookProjection} ${astralProjection} ${leonardoProjection} ${ponytailProjection}; do
          test ! -e "$projection/setup.sh"
          test ! -e "$projection/hooks"
          test ! -e "$projection/.claude"
          test ! -e "$projection/.github"
        done
        touch "$out"
      '';
  all-skills = allSkills;
}
