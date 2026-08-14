{ inputs, lib, ... }:
let
  validName = name: builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null;

  discover =
    kind: root:
    lib.mapAttrs (
      name: type:
      assert lib.assertMsg (type == "directory") "${kind}/${name} must be a directory";
      assert lib.assertMsg (validName name) "Invalid ${kind} resource name: ${name}";
      let
        manifestPath = root + "/${name}/default.nix";
        manifest = import manifestPath { inherit inputs; };
        allowed = [
          "actions"
          "defaultEnable"
          "description"
          "environment"
          "homepage"
          "id"
          "package"
          "pluginRoot"
          "requiresTargets"
          "source"
          "title"
          "version"
        ];
        isHerdrPlugin = kind == "herdr-plugins";
        unknown = lib.subtractLists allowed (builtins.attrNames manifest);
      in
      assert lib.assertMsg (builtins.pathExists manifestPath) "${kind}/${name} is missing default.nix";
      assert lib.assertMsg (unknown == [ ]) "${kind}/${name} has unknown fields: ${toString unknown}";
      assert lib.assertMsg (
        builtins.isString manifest.title && manifest.title != ""
      ) "${kind}/${name}.title must be non-empty";
      assert lib.assertMsg (
        builtins.isString manifest.description && manifest.description != ""
      ) "${kind}/${name}.description must be non-empty";
      assert lib.assertMsg (
        !(manifest ? defaultEnable) || builtins.isBool manifest.defaultEnable
      ) "${kind}/${name}.defaultEnable must be a Boolean";
      assert lib.assertMsg (
        !isHerdrPlugin || !(manifest ? defaultEnable)
      ) "${kind}/${name} cannot override its opt-in default";
      assert lib.assertMsg (
        !(manifest ? actions)
        || (builtins.isList manifest.actions && builtins.all builtins.isString manifest.actions)
      ) "${kind}/${name}.actions must be a list of strings";
      assert lib.assertMsg (
        isHerdrPlugin || manifest ? source || manifest ? package
      ) "${kind}/${name} needs source or package";
      assert lib.assertMsg (
        isHerdrPlugin || !(manifest ? source && manifest ? package)
      ) "${kind}/${name} cannot have both source and package";
      assert lib.assertMsg (
        !(manifest ? source) || builtins.pathExists manifest.source
      ) "${kind}/${name}.source does not exist";
      assert lib.assertMsg (
        !isHerdrPlugin
        || (
          manifest ? id
          && builtins.isString manifest.id
          && manifest.id != ""
          && manifest ? version
          && builtins.isString manifest.version
          && manifest.version != ""
          && manifest ? package
          && builtins.isFunction manifest.package
          && manifest ? pluginRoot
          && builtins.isFunction manifest.pluginRoot
        )
      ) "${kind}/${name} needs an id, version, package builder, and plugin-root builder";
      manifest
      // {
        inherit kind name;
        actions = manifest.actions or [ ];
        defaultEnable = if isHerdrPlugin then false else manifest.defaultEnable or true;
        environment = manifest.environment or { };
        requiresTargets = manifest.requiresTargets or [ ];
      }
    ) (builtins.readDir root);
in
{
  options.dendriticSlopInternal.resources = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    internal = true;
  };

  config.dendriticSlopInternal.resources = {
    skills = discover "skills" ../resources/skills;
    extensions = discover "extensions" ../resources/extensions;
    herdrPlugins = discover "herdr-plugins" ../resources/herdr-plugins;
  };
}
