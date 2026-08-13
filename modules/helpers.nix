{ lib, ... }:
let
  targetNames = [
    "context7"
    "git"
    "herdr"
    "pi"
    "rules"
    "skills"
  ];

  isValidSkillName =
    name:
    builtins.isString name
    && builtins.stringLength name <= 64
    && builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null;

  mkSkill =
    {
      pkgs,
      name,
      text,
      formatter ? null,
      formatterArgs ? [ ],
    }:
    assert lib.assertMsg (isValidSkillName name)
      "Skill names must be lowercase alphanumeric words separated by single hyphens";
    assert lib.assertMsg (builtins.isString text) "Skill text must be a string";
    assert lib.assertMsg (
      formatter == null || lib.isDerivation formatter
    ) "Skill formatter must be a package or null";
    pkgs.writeTextFile {
      name = "agent-skill-${name}";
      destination = "/${name}/SKILL.md";
      inherit text;
      checkPhase = ''
        ${lib.optionalString (formatter != null) ''
          ${lib.getExe formatter} ${lib.escapeShellArgs formatterArgs} "$target"
        ''}
        ${pkgs.gnugrep}/bin/grep -Fqx -- ${lib.escapeShellArg "name: ${name}"} "$target"
        ${pkgs.gnugrep}/bin/grep -Eq '^description:[[:space:]]+.' "$target"
      '';
    };
in
{
  options.dendriticSlopInternal.homeManagerTargets = lib.mkOption {
    type = lib.types.listOf lib.types.deferredModule;
    default = [ ];
    internal = true;
  };

  config.flake.lib = {
    inherit isValidSkillName mkSkill targetNames;

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
