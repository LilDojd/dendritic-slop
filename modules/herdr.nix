{ config, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  herdrPlugins = config.dendriticSlopInternal.catalog.herdrPlugins;
  herdrTool = config.dendriticSlopInternal.catalog.tools.herdr;
  realizedPluginsFor = config.dendriticSlopInternal.realized.herdrPlugins;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dendriticSlop;
      herdrPackage = herdrTool.package pkgs;
      herdrPackageVersion = herdrPackage.version or null;
      herdrSourceVersion = herdrTool.sourceVersion;
      herdrVersionsAgree =
        herdrPackageVersion == null
        || herdrSourceVersion == null
        || herdrPackageVersion == herdrSourceVersion;
      herdr = lib.getExe herdrPackage;
      awk = lib.getExe pkgs.gawk;
      jq = lib.getExe pkgs.jq;
      stateDir = "${config.xdg.stateHome}/dendritic-slop/herdr-plugins";
      realizedPlugins = realizedPluginsFor pkgs;

      pluginOptions = lib.mapAttrs (_: resource: {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          defaultText = lib.literalExpression "false";
          description = "Whether to enable the ${resource.title} Herdr plugin. ${resource.description}";
        };
      }) herdrPlugins;

      pluginEnabled = name: cfg.enable && cfg.targets.herdr.enable && cfg.herdr.plugins.${name}.enable;
      pluginNames = builtins.attrNames herdrPlugins;
      enabledPluginNames = lib.filter pluginEnabled pluginNames;
      pluginsMeetMinimumVersion = lib.all (
        name:
        herdrPackageVersion == null
        || lib.versionAtLeast herdrPackageVersion herdrPlugins.${name}.minimumHerdrVersion
      ) enabledPluginNames;

      keybindingsBegin = name: "# BEGIN dendritic-slop ${name} keybindings";
      keybindingsEnd = name: "# END dendritic-slop ${name} keybindings";
      keybindingsToml =
        resource:
        lib.concatMapStringsSep "\n" (binding: ''
          [[keys.command]]
          key = ${builtins.toJSON binding.key}
          type = "plugin_action"
          command = ${builtins.toJSON binding.command}
          description = ${builtins.toJSON binding.description}
        '') resource.keybindings;
      pluginsWithKeybindings = lib.filter (name: herdrPlugins.${name}.keybindings != [ ]) pluginNames;
      enabledPluginsWithKeybindings = lib.filter pluginEnabled pluginsWithKeybindings;
      existingMarkerCondition = lib.concatMapStringsSep " || " (
        name: "${pkgs.gnugrep}/bin/grep -Fqx ${lib.escapeShellArg (keybindingsBegin name)} \"$config_file\""
      ) pluginsWithKeybindings;
      stripManagedKeybindings = lib.concatMapStringsSep "\n" (name: ''
        $0 == ${builtins.toJSON (keybindingsBegin name)} { managed = 1; next }
        $0 == ${builtins.toJSON (keybindingsEnd name)} { managed = 0; next }
      '') pluginsWithKeybindings;
      renderedKeybindings = lib.concatMapStringsSep "\n" (name: ''
        printf '\n%s\n%s\n%s\n' \
          ${lib.escapeShellArg (keybindingsBegin name)} \
          ${lib.escapeShellArg (keybindingsToml herdrPlugins.${name})} \
          ${lib.escapeShellArg (keybindingsEnd name)} >> "$config_tmp"
      '') enabledPluginsWithKeybindings;
      renderKeybindings = lib.optionalString (pluginsWithKeybindings != [ ]) ''
        config_file=${lib.escapeShellArg "${config.xdg.configHome}/herdr/config.toml"}
        if [ ${if enabledPluginsWithKeybindings == [ ] then "0" else "1"} = 1 ] || \
          { [ -f "$config_file" ] && { ${existingMarkerCondition}; }; }; then
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$config_file")"
          config_tmp="$(${pkgs.coreutils}/bin/mktemp "$config_file.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -f "$config_tmp"' EXIT

          if [ -f "$config_file" ]; then
            ${awk} '
              ${stripManagedKeybindings}
              !managed { print }
            ' "$config_file" > "$config_tmp"
          fi

          ${renderedKeybindings}
          HERDR_CONFIG_PATH="$config_tmp" ${herdr} config check >/dev/null
          ${pkgs.coreutils}/bin/chmod 0600 "$config_tmp"
          ${pkgs.coreutils}/bin/mv -f "$config_tmp" "$config_file"
          trap - EXIT
          ${herdr} server reload-config >/dev/null 2>&1 || true
        fi
      '';

      managePluginCalls = lib.concatMapStringsSep "\n" (
        name:
        let
          resource = herdrPlugins.${name};
          realized = realizedPlugins.${name};
        in
        ''
          manage_plugin \
            ${lib.escapeShellArg name} \
            ${lib.escapeShellArg resource.pluginId} \
            ${if pluginEnabled name then "1" else "0"} \
            ${lib.escapeShellArg (lib.optionalString (pluginEnabled name) (toString realized.root))}
        ''
      ) pluginNames;

      managePlugins = pkgs.writeShellScript "dendritic-slop-herdr-plugins" ''
        set -eu

        ${renderKeybindings}

        manage_plugin() {
          name="$1"
          plugin_id="$2"
          desired="$3"
          new_root="$4"
          marker=${lib.escapeShellArg stateDir}/"$name"

          if [ "$desired" = 0 ] && [ ! -e "$marker" ]; then
            return
          fi

          ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${lib.escapeShellArg stateDir}
          inspect_error="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${stateDir}/inspect.XXXXXX"})"
          if current_json="$(${herdr} plugin list --json --plugin "$plugin_id" 2>"$inspect_error")"; then
            ${pkgs.coreutils}/bin/rm -f "$inspect_error"
          elif ${pkgs.gnugrep}/bin/grep -Fq '"code":"protocol_mismatch"' "$inspect_error"; then
            ${pkgs.coreutils}/bin/cat "$inspect_error" >&2
            echo "dendritic-slop: deferring Herdr plugin $plugin_id reconciliation until the Herdr server is restarted with the installed client version" >&2
            ${pkgs.coreutils}/bin/rm -f "$inspect_error"
            return
          else
            ${pkgs.coreutils}/bin/cat "$inspect_error" >&2
            ${pkgs.coreutils}/bin/rm -f "$inspect_error"
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
        }

        ${managePluginCalls}
      '';
    in
    {
      options = {
        dendriticSlop = {
          targets.herdr.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Install Herdr.";
          };
          herdr.plugins = pluginOptions;
        };
        dendriticSlopInternal.herdr.manageScript = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          internal = true;
        };
      };

      config = lib.mkMerge [
        {
          dendriticSlopInternal.herdr.manageScript = managePlugins;
          home.activation.dendriticSlopHerdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${managePlugins}
          '';

          assertions = [
            {
              assertion = herdrVersionsAgree;
              message = "Herdr source version ${toString herdrSourceVersion} disagrees with package version ${toString herdrPackageVersion}";
            }
            {
              assertion =
                !cfg.enable
                || cfg.targets.herdr.enable
                || lib.all (name: !cfg.herdr.plugins.${name}.enable) pluginNames;
              message = "Herdr plugins require dendriticSlop.targets.herdr.enable = true";
            }
            {
              assertion = pluginsMeetMinimumVersion;
              message = "A selected Herdr plugin requires a newer Herdr package";
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
