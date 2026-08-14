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
