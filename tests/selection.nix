{
  bridgeFalse,
  bridgeTrue,
  bridgeUnset,
  catalog,
  catalogEvaluation,
  config,
  distinctPlugin,
  duplicateExposedName,
  duplicateMcpId,
  duplicatePluginExecutable,
  duplicatePluginId,
  duplicatePluginKey,
  duplicatePluginSource,
  home,
  homeWithDisabledHerdr,
  homeWithDisabledPi,
  homeWithMissingAdapter,
  homeWithProfiles,
  homeWithStandalonePi,
  homeWithStandaloneSkill,
  invalidExtensionVariant,
  invalidMcpVariant,
  lib,
  pkgs,
  pluginCollision,
  pluginPackageWithoutVersion,
  pluginVersionMismatch,
  profileExecutableCollision,
  unsupportedPackage,
  validSelection,
  ...
}:
{
  profile-selection =
    assert !(home.options.dendriticSlop ? autoEnable);
    assert !builtins.hasAttr "actionbook-rust" home.options.dendriticSlop.skills;
    assert !builtins.hasAttr "astral-python" home.options.dendriticSlop.skills;
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
    assert homeWithProfiles.config.dendriticSlop.skills.rust-skills.enable;
    assert homeWithProfiles.config.dendriticSlop.extensions.ask-user.enable;
    assert homeWithProfiles.config.dendriticSlop.extensions.herdr-agent-state.enable;
    assert homeWithProfiles.config.dendriticSlop.extensions.pi-mcp-adapter.enable;
    assert homeWithProfiles.config.dendriticSlop.tools.herdr.enable;
    assert homeWithProfiles.config.dendriticSlop.tools.pi.enable;
    assert !homeWithProfiles.config.dendriticSlop.targets.git.enable;
    assert homeWithProfiles.config.dendriticSlop.targets.herdr.enable;
    assert homeWithProfiles.config.dendriticSlop.targets.pi.enable;
    assert homeWithProfiles.config.dendriticSlop.targets.rules.enable;
    assert !homeWithDisabledPi.success;
    assert !homeWithDisabledHerdr.success;
    assert !homeWithMissingAdapter.success;
    assert homeWithStandalonePi.config.programs.pi.coding-agent.enable;
    assert homeWithStandaloneSkill.config.dendriticSlop.skills.bro.enable;
    assert bridgeUnset.profiles.core.enable && bridgeUnset.skills.ty.enable;
    assert bridgeTrue.profiles.core.enable && bridgeTrue.skills.ty.enable;
    assert !bridgeFalse.profiles.core.enable && !bridgeFalse.skills.ty.enable;
    pkgs.runCommand "profile-selection-check" { } ''
      touch "$out"
    '';
  registry-schema =
    assert catalogEvaluation.success;
    assert !invalidMcpVariant.success;
    assert !invalidExtensionVariant.success;
    assert !duplicateExposedName;
    assert !duplicateMcpId;
    assert pluginCollision (distinctPlugin { });
    assert validSelection catalog { herdrPlugins.jj-workspace = true; };
    assert !duplicatePluginSource;
    assert !duplicatePluginId;
    assert !duplicatePluginExecutable;
    assert !duplicatePluginKey;
    assert !pluginVersionMismatch.success;
    assert pluginPackageWithoutVersion.success;
    assert !profileExecutableCollision.success;
    assert !unsupportedPackage;
    assert (builtins.head catalog.skills.jujutsu.runtimeExecutables).package pkgs == pkgs.jujutsu;
    assert catalog.extensions.pi-mcp-adapter.realization.packageId == "pi-mcp-adapter";
    pkgs.runCommand "registry-schema-check" { } ''
      touch "$out"
    '';
}
