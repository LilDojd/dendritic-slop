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

  mkSkill =
    {
      pkgs,
      name,
      source,
      extraFiles ? [ ],
      runtimeInputs ? [ ],
    }:
    assert lib.assertMsg (isValidSkillName name)
      "Skill names must be lowercase alphanumeric words separated by single hyphens";
    assert lib.assertMsg (builtins.pathExists source) "Skill source does not exist";
    assert lib.assertMsg (builtins.all builtins.pathExists extraFiles)
      "A skill extra file does not exist";
    assert lib.assertMsg (builtins.all lib.isDerivation runtimeInputs)
      "Skill runtime inputs must be packages";
    let
      sourcePath = builtins.path {
        path = source;
        name = "agent-skill-${name}-source";
      };
      copiedExtraFiles = map (file: {
        name = builtins.baseNameOf file;
        path = builtins.path {
          path = file;
          name = "agent-skill-${name}-${builtins.baseNameOf file}";
        };
      }) extraFiles;
    in
    pkgs.runCommand "agent-skill-${name}"
      {
        nativeBuildInputs = runtimeInputs;
        passthru = { inherit runtimeInputs; };
      }
      ''
        destination="$out/${name}"
        mkdir -p "$destination"
        if [ -d ${lib.escapeShellArg sourcePath} ]; then
          cp -R ${lib.escapeShellArg "${sourcePath}/."} "$destination/"
        else
          cp ${lib.escapeShellArg sourcePath} "$destination/SKILL.md"
        fi
        ${lib.concatMapStringsSep "\n" (file: ''
          cp ${lib.escapeShellArg file.path} "$destination/${file.name}"
        '') copiedExtraFiles}
        chmod -R u+w "$destination"
        patchShebangs "$destination"
        target="$destination/SKILL.md"
        test -f "$target"
        ${pkgs.gnugrep}/bin/grep -Fqx -- ${lib.escapeShellArg "name: ${name}"} "$target"
        ${pkgs.gnugrep}/bin/grep -Eq '^description:[[:space:]]+.' "$target"
      '';
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
