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
      awk = lib.getExe pkgs.gawk;
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
          keybindingsBegin = "# BEGIN dendritic-slop ${name} keybindings";
          keybindingsEnd = "# END dendritic-slop ${name} keybindings";
          keybindingsToml = lib.concatMapStringsSep "\n" (binding: ''
            [[keys.command]]
            key = ${builtins.toJSON binding.key}
            type = "plugin_action"
            command = ${builtins.toJSON binding.command}
            description = ${builtins.toJSON binding.description}
          '') resource.keybindings;
          manageKeybindings = lib.optionalString (resource.keybindings != [ ]) ''
            config_file=${lib.escapeShellArg "${config.xdg.configHome}/herdr/config.toml"}
            bindings_begin=${lib.escapeShellArg keybindingsBegin}
            bindings_end=${lib.escapeShellArg keybindingsEnd}

            if [ "$desired" = 1 ] || { [ -f "$config_file" ] && ${pkgs.gnugrep}/bin/grep -Fqx "$bindings_begin" "$config_file"; }; then
              ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$config_file")"
              config_tmp="$(${pkgs.coreutils}/bin/mktemp "$config_file.XXXXXX")"
              trap '${pkgs.coreutils}/bin/rm -f "$config_tmp"' EXIT

              if [ -f "$config_file" ]; then
                ${awk} -v begin="$bindings_begin" -v end="$bindings_end" '
                  $0 == begin { managed = 1; next }
                  $0 == end { managed = 0; next }
                  !managed { print }
                ' "$config_file" > "$config_tmp"
              fi

              if [ "$desired" = 1 ]; then
                printf '\n%s\n%s\n%s\n' \
                  "$bindings_begin" \
                  ${lib.escapeShellArg keybindingsToml} \
                  "$bindings_end" >> "$config_tmp"
              fi

              HERDR_CONFIG_PATH="$config_tmp" ${herdr} config check >/dev/null
              ${pkgs.coreutils}/bin/chmod 0600 "$config_tmp"
              ${pkgs.coreutils}/bin/mv -f "$config_tmp" "$config_file"
              trap - EXIT
              ${herdr} server reload-config >/dev/null 2>&1 || true
            fi
          '';
        in
        pkgs.writeShellScript "dendritic-slop-herdr-plugin-${name}" ''
          set -eu

          marker=${lib.escapeShellArg "${stateDir}/${name}"}
          desired=${desired}
          plugin_id=${lib.escapeShellArg resource.id}
          new_root=${lib.escapeShellArg root}

          ${manageKeybindings}

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
