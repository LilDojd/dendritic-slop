{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      testUser = "slop-test";

      mkHome =
        extraModule:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            config.flake.modules.homeManager.slop
            {
              dendriticSlop.enable = true;
              home = {
                username = testUser;
                homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${testUser}" else "/home/${testUser}";
                stateVersion = "25.11";
              };
            }
            extraModule
          ];
        };

      home = mkHome { };
      homeWithWebAccess = mkHome {
        dendriticSlop.extensions.web-access.enable = true;
      };
      homeWithJjWorkspace = mkHome {
        dendriticSlop.herdr.plugins.jj-workspace.enable = true;
      };
      jjWorkspaceResource = config.dendriticSlopInternal.resources.herdrPlugins.jj-workspace;
      jjWorkspacePackage = jjWorkspaceResource.package pkgs;
      jjWorkspaceRoot = jjWorkspaceResource.pluginRoot pkgs;
      defaultJjWorkspaceActivation =
        home.config.home.activation."dendriticSlopHerdrPlugin-jj-workspace".data;
      jjWorkspaceActivation =
        homeWithJjWorkspace.config.home.activation."dendriticSlopHerdrPlugin-jj-workspace".data;
      jjWorkspaceManifest = pkgs.runCommand "herdr-plugin-jj-workspace-manifest-check" { } ''
        test -x ${jjWorkspaceRoot}/target/release/jj-workspace
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "nathanflurry.jj-workspace"' ${jjWorkspaceRoot}/herdr-plugin.toml
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "new"' ${jjWorkspaceRoot}/herdr-plugin.toml
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "new-tab"' ${jjWorkspaceRoot}/herdr-plugin.toml
        ${pkgs.gnugrep}/bin/grep -Fqx 'id = "remove"' ${jjWorkspaceRoot}/herdr-plugin.toml
        touch "$out"
      '';
      webAccessPackage = config.dendriticSlopInternal.resources.extensions.web-access.package;
      defaultPackages = home.config.programs.pi.coding-agent.settings.packages;
      optedInPackages = homeWithWebAccess.config.programs.pi.coding-agent.settings.packages;

      nixos = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.impermanence.nixosModules.impermanence
          config.flake.modules.nixos.slop
          {
            dendriticSlop = {
              enable = true;
              username = testUser;
            };
            boot.loader.grub.devices = [ "nodev" ];
            fileSystems = {
              "/" = {
                device = "none";
                fsType = "tmpfs";
              };
              "/persistent" = {
                device = "none";
                fsType = "tmpfs";
                neededForBoot = true;
              };
            };
            home-manager.users.${testUser}.home.stateVersion = "25.11";
            system.stateVersion = "25.11";
            users.users.${testUser}.isNormalUser = true;
          }
        ];
      };

      darwin = inputs.nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          inputs.home-manager.darwinModules.home-manager
          config.flake.modules.darwin.slop
          {
            dendriticSlop = {
              enable = true;
              username = testUser;
            };
            home-manager.users.${testUser}.home.stateVersion = "25.11";
            system.stateVersion = 6;
            users.users.${testUser}.home = "/Users/${testUser}";
          }
        ];
      };

      herdrSkillText = builtins.readFile config.dendriticSlopInternal.resources.skills.herdr.source;
      allSkills = pkgs.symlinkJoin {
        name = "all-dendritic-slop-skills";
        paths = lib.mapAttrsToList (
          name: resource:
          config.flake.lib.mkSkill {
            inherit pkgs name;
            text = builtins.readFile resource.source;
          }
        ) config.dendriticSlopInternal.resources.skills;
      };
    in
    {
      checks = {
        all-skills =
          assert lib.hasInfix "--kind pi" herdrSkillText;
          assert !(lib.hasInfix "--kind codex" herdrSkillText);
          assert lib.hasInfix "Use Pi unless the user explicitly requests another supported agent kind" herdrSkillText;
          allSkills;
        home-manager-module =
          assert !builtins.elem webAccessPackage defaultPackages;
          home.activationPackage;
        web-access-opt-in =
          assert builtins.elem webAccessPackage optedInPackages;
          homeWithWebAccess.activationPackage;
        herdr-plugin-jj-workspace-package = jjWorkspacePackage;
        herdr-plugin-jj-workspace-root = jjWorkspaceRoot;
        herdr-plugin-jj-workspace-manifest = jjWorkspaceManifest;
        herdr-plugin-jj-workspace-opt-in =
          assert !home.config.dendriticSlop.herdr.plugins.jj-workspace.enable;
          assert homeWithJjWorkspace.config.dendriticSlop.herdr.plugins.jj-workspace.enable;
          assert builtins.isString defaultJjWorkspaceActivation && defaultJjWorkspaceActivation != "";
          assert builtins.isString jjWorkspaceActivation && jjWorkspaceActivation != "";
          assert defaultJjWorkspaceActivation != jjWorkspaceActivation;
          homeWithJjWorkspace.activationPackage;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        nixos-module = nixos.config.system.build.toplevel;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        darwin-module = darwin.system;
      };

      formatter = pkgs.nixfmt-tree;
      packages.all-skills = allSkills;
    };
}
