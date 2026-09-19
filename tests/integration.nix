{
  catalog,
  config,
  darwin,
  defaultPackages,
  herdrAgentStateResource,
  home,
  lib,
  managedHerdrAgentState,
  managedSkills,
  nixos,
  pkgs,
  profilePackages,
  system,
  testUser,
  webAccessPackage,
  ...
}:
{
  home-manager-module =
    assert home.config.programs.pi.coding-agent.extensions == [ ];
    assert home.config.programs.pi.coding-agent.skills == [ ];
    assert lib.all (
      name: !home.config.dendriticSlop.skills.${name}.enable
    ) catalog.profiles.superpowers.members.skills;
    assert managedHerdrAgentState.source == herdrAgentStateResource.realization.source;
    assert managedHerdrAgentState.force;
    assert !managedSkills.force;
    assert !builtins.elem webAccessPackage defaultPackages;
    home.activationPackage;
}
// lib.mapAttrs' (
  name: package:
  lib.nameValuePair "all-${name}" (
    assert package.manifest.profile == name;
    assert package.manifest.targets == catalog.profiles.${name}.targets;
    assert package.manifest.resources == catalog.profiles.${name}.members;
    package
  )
) profilePackages
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
  darwin-module = darwin.system;
}
