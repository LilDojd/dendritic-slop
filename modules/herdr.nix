{ config, inputs, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  inherit (config.flake.lib) mkEnableTarget;
  herdrPlugins = config.dendriticSlopInternal.resources.herdrPlugins;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dendriticSlop;
      herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      herdr = lib.getExe herdrPackage;
      jq = lib.getExe pkgs.jq;
      stateDir = "${config.xdg.stateHome}/dendritic-slop/herdr-plugins";

      pluginOptions = lib.mapAttrs (_: resource: {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          defaultText = lib.literalExpression "false";
          description = "Whether to enable the ${resource.title} Herdr plugin. ${resource.description}";
        };
      }) herdrPlugins;

      pluginRoots = lib.mapAttrs (_: resource: resource.pluginRoot pkgs) herdrPlugins;
      pluginEnabled = name: cfg.enable && cfg.targets.herdr.enable && cfg.herdr.plugins.${name}.enable;

      managePlugin =
        name: resource:
        let
          desired = if pluginEnabled name then "1" else "0";
          root = lib.optionalString (pluginEnabled name) (toString pluginRoots.${name});
        in
        pkgs.writeShellScript "dendritic-slop-herdr-plugin-${name}" ''
          set -eu

          marker=${lib.escapeShellArg "${stateDir}/${name}"}
          desired=${desired}
          plugin_id=${lib.escapeShellArg resource.id}
          new_root=${lib.escapeShellArg root}

          if [ "$desired" = 0 ] && [ ! -e "$marker" ]; then
            exit 0
          fi

          ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${lib.escapeShellArg stateDir}
          if ! current_json="$(${herdr} plugin list --json --plugin "$plugin_id" 2>/dev/null)"; then
            echo "dendritic-slop: failed to inspect Herdr plugin $plugin_id" >&2
            exit 1
          fi
          current_kind="$(printf '%s' "$current_json" | ${jq} -r '.result.plugins[0].source.kind // ""')"
          current_root="$(printf '%s' "$current_json" | ${jq} -r '.result.plugins[0].plugin_root // ""')"
          owned_root=
          if [ -r "$marker" ]; then
            IFS= read -r owned_root < "$marker" || true
          fi

          write_marker() {
            printf '%s\n' "$new_root" > "$marker.tmp"
            ${pkgs.coreutils}/bin/chmod 0600 "$marker.tmp"
            ${pkgs.coreutils}/bin/mv -f "$marker.tmp" "$marker"
          }

          if [ "$desired" = 1 ]; then
            if [ -n "$owned_root" ]; then
              if [ -z "$current_root" ] ||
                { [ "$current_kind" = local ] && { [ "$current_root" = "$owned_root" ] || [ "$current_root" = "$new_root" ]; }; }; then
                ${herdr} plugin link "$new_root" >/dev/null
                write_marker
              else
                echo "dendritic-slop: Herdr plugin $plugin_id is no longer owned by dendritic-slop; leaving the registration at $current_root unchanged" >&2
                ${pkgs.coreutils}/bin/rm -f "$marker"
              fi
            elif [ -z "$current_root" ]; then
              ${herdr} plugin link "$new_root" >/dev/null
              write_marker
            else
              echo "dendritic-slop: Herdr plugin $plugin_id is registered from $current_root; leaving that registration unchanged" >&2
            fi
          elif [ -n "$owned_root" ]; then
            if [ -z "$current_root" ]; then
              ${pkgs.coreutils}/bin/rm -f "$marker"
            elif [ "$current_kind" = local ] && [ "$current_root" = "$owned_root" ]; then
              ${herdr} plugin unlink "$plugin_id" >/dev/null
              ${pkgs.coreutils}/bin/rm -f "$marker"
            else
              echo "dendritic-slop: Herdr plugin $plugin_id is no longer owned by dendritic-slop; leaving the registration at $current_root unchanged" >&2
              ${pkgs.coreutils}/bin/rm -f "$marker"
            fi
          fi
        '';

      activationEntries = lib.mapAttrs' (
        name: resource:
        lib.nameValuePair "dendriticSlopHerdrPlugin-${name}" (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${managePlugin name resource}
          ''
        )
      ) herdrPlugins;
    in
    {
      options.dendriticSlop = {
        targets.herdr.enable = mkEnableTarget {
          inherit config lib;
          description = "Install Herdr.";
        };
        herdr.plugins = pluginOptions;
      };

      config = lib.mkMerge [
        {
          home.activation = activationEntries;

          assertions = [
            {
              assertion =
                !cfg.enable
                || cfg.targets.herdr.enable
                || lib.all (name: !cfg.herdr.plugins.${name}.enable) (builtins.attrNames herdrPlugins);
              message = "Herdr plugins require dendriticSlop.targets.herdr.enable = true";
            }
          ];
        }
        (lib.mkIf (cfg.enable && cfg.targets.herdr.enable) {
          home.packages = [ herdrPackage ];
        })
      ];
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.herdr.imports = [
    coreModule
    targetModule
  ];
}
