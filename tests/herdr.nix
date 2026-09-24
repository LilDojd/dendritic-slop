{
  catalog,
  defaultHerdrManageScript,
  defaultJjWorkspaceActivation,
  enabledHerdrManageScript,
  herdrPackage,
  home,
  homeWithJjWorkspace,
  jjWorkspaceActivation,
  jjWorkspaceManifest,
  jjWorkspacePackage,
  jjWorkspaceResource,
  jjWorkspaceRoot,
  lib,
  pkgs,
  ...
}:
{
  herdr-plugin-registry =
    let
      plugins = builtins.attrValues catalog.herdrPlugins;
      pluginIds = map (plugin: plugin.pluginId) plugins;
      pluginSources = map (plugin: toString plugin.source) plugins;
      pluginExecutables = map (plugin: plugin.executable) plugins;
      pluginKeys = lib.concatMap (plugin: map (binding: binding.key) plugin.keybindings) plugins;
      sourceManifest = builtins.fromTOML (
        builtins.readFile (jjWorkspaceResource.source + "/herdr-plugin.toml")
      );
      packageVersion = jjWorkspacePackage.version or null;
      herdrPackageVersion = herdrPackage.version or null;
    in
    assert lib.unique pluginIds == pluginIds;
    assert lib.unique pluginSources == pluginSources;
    assert lib.unique pluginExecutables == pluginExecutables;
    assert lib.unique pluginKeys == pluginKeys;
    assert sourceManifest.id == jjWorkspaceResource.pluginId;
    assert sourceManifest.version == jjWorkspaceResource.version;
    assert sourceManifest.min_herdr_version == jjWorkspaceResource.minimumHerdrVersion;
    assert packageVersion == null || packageVersion == sourceManifest.version;
    assert
      herdrPackageVersion == null
      || catalog.tools.herdr.sourceVersion == null
      || herdrPackageVersion == catalog.tools.herdr.sourceVersion;
    assert
      builtins.attrNames (
        lib.filterAttrs (name: _: lib.hasPrefix "dendriticSlopHerdrPlugin" name) home.config.home.activation
      ) == [ "dendriticSlopHerdrPlugins" ];
    pkgs.runCommand "herdr-plugin-registry-check" { } ''
      ${pkgs.bash}/bin/bash -n ${defaultHerdrManageScript}
      ${pkgs.bash}/bin/bash -n ${enabledHerdrManageScript}
      touch "$out"
    '';
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
