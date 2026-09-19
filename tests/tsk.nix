{
  catalog,
  config,
  home,
  lib,
  mkHome,
  pkgs,
  ...
}:
let
  package = catalog.tools.tsk.package pkgs;
  plugin = (config.dendriticSlopInternal.realized.herdrPlugins pkgs).tsk.root;
  standalone = mkHome { dendriticSlop.tools.tsk.enable = true; };
  enabled = mkHome {
    dendriticSlop = {
      tools.tsk.enable = true;
      tools.herdr.enable = true;
      skills.tsk-cli.enable = true;
      herdr.plugins.tsk.enable = true;
    };
  };
in
{
  tsk =
    assert !home.config.dendriticSlop.tools.tsk.enable;
    assert !home.config.dendriticSlop.skills.tsk-cli.enable;
    assert !home.config.dendriticSlop.herdr.plugins.tsk.enable;
    assert lib.elem package standalone.config.home.packages;
    assert lib.elem package enabled.config.home.packages;
    assert enabled.config.dendriticSlop.targets.herdr.enable;
    pkgs.runCommand "tsk-check" { } ''
      ${package}/bin/tsk --help > /dev/null
      test -x ${plugin}/target/release/tsk
      ${pkgs.bash}/bin/bash -n ${plugin}/scripts/open-board.sh
      ${pkgs.bash}/bin/bash -n ${plugin}/scripts/open-capture.sh
      test -f ${enabled.config.home.file.".agents/skills".source}/tsk-cli/SKILL.md
      touch "$out"
    '';
}
