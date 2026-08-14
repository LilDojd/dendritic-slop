{ config, lib, ... }:
let
  catalog = config.dendriticSlopInternal.catalog;
  resourcesModule = config.flake.modules.homeManager.resources;

  runtimeSecretPath = lib.types.addCheck lib.types.str (
    path:
    lib.hasPrefix "/" path && path != builtins.storeDir && !lib.hasPrefix "${builtins.storeDir}/" path
  );

  mcpOptions = lib.mapAttrs (_: resource: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable ${resource.title}. ${resource.description}";
    };
    secrets = lib.mapAttrs (
      _: secret:
      lib.mkOption {
        type = lib.types.nullOr runtimeSecretPath;
        default = null;
        description = secret.description;
        example = "/run/agenix/runtime-secret";
      }
    ) resource.secretFiles;
  }) catalog.mcps;

  taggedSubmodule =
    tag: module: lib.types.addCheck (lib.types.submodule module) (value: (value.type or null) == tag);

  localTransport = taggedSubmodule "local" {
    options = {
      type = lib.mkOption { type = lib.types.enum [ "local" ]; };
      command = lib.mkOption { type = lib.types.str; };
      arguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  remoteTransport = taggedSubmodule "remote" {
    options = {
      type = lib.mkOption { type = lib.types.enum [ "remote" ]; };
      url = lib.mkOption { type = lib.types.str; };
      headers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
    };
  };

  serverContributionModule = {
    options = {
      owner = lib.mkOption { type = lib.types.str; };
      serverId = lib.mkOption { type = lib.types.str; };
      transport = lib.mkOption {
        type = lib.types.oneOf [
          localTransport
          remoteTransport
        ];
      };
      lifecycle = lib.mkOption {
        type = lib.types.enum [
          "eager"
          "keep-alive"
          "lazy"
          "lazy-keep-alive"
        ];
        default = "lazy";
      };
      piProcessEnvironment = lib.mkOption {
        type = lib.types.attrsOf runtimeSecretPath;
        default = { };
      };
    };
  };

  targetModule =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      enabledMcps = lib.filterAttrs (name: _: config.dendriticSlop.mcps.${name}.enable) catalog.mcps;

      contributionFor =
        name: resource:
        let
          configuredSecrets = lib.filterAttrs (
            secretName: _: config.dendriticSlop.mcps.${name}.secrets.${secretName} != null
          ) resource.secretFiles;
          secretHeaders = lib.foldl' (
            headers: secretName: headers // resource.secretFiles.${secretName}.headers
          ) { } (builtins.attrNames configuredSecrets);
          piProcessEnvironment = lib.mapAttrs' (
            secretName: secret:
            lib.nameValuePair secret.environment (config.dendriticSlop.mcps.${name}.secrets.${secretName})
          ) configuredSecrets;
          transport =
            if resource.transport.type == "local" then
              {
                type = "local";
                command = lib.getExe' (resource.transport.package pkgs) resource.transport.executable;
                inherit (resource.transport) arguments;
              }
            else
              {
                type = "remote";
                inherit (resource.transport) url;
                headers = resource.transport.headers // secretHeaders;
              };
        in
        {
          owner = "mcps.${name}";
          inherit (resource) serverId lifecycle;
          inherit transport piProcessEnvironment;
        };

      selectedContributions = lib.mapAttrsToList contributionFor enabledMcps;
      contributions = config.dendriticSlopInternal.mcp.servers;
      serverIds = map (contribution: contribution.serverId) contributions;
      duplicateServerIds = lib.filter (
        serverId: builtins.length (lib.filter (candidate: candidate == serverId) serverIds) > 1
      ) (lib.unique serverIds);

      environmentEntries = lib.concatMap (
        contribution:
        lib.mapAttrsToList (name: path: { inherit name path; }) contribution.piProcessEnvironment
      ) contributions;
      environmentGroups = lib.groupBy (entry: entry.name) environmentEntries;
      conflictingEnvironmentNames = builtins.attrNames (
        lib.filterAttrs (
          _: entries: builtins.length (lib.unique (map (entry: entry.path) entries)) > 1
        ) environmentGroups
      );
      piProcessEnvironment = lib.mapAttrs (_: entries: {
        file = (builtins.head entries).path;
      }) environmentGroups;

      enabledExtensions = lib.filterAttrs (name: _: config.dendriticSlop.extensions.${name}.enable) (
        config.dendriticSlop.extensions or { }
      );
      unsafeExtensionNames = builtins.attrNames (
        lib.filterAttrs (name: _: !(catalog.extensions.${name}.secretCapable or false)) enabledExtensions
      );
      hasPiProcessSecrets = environmentEntries != [ ];

      invalidSecretHeaderMcps = builtins.attrNames (
        lib.filterAttrs (
          _name: resource:
          let
            secretHeaderNames = lib.concatMap (secret: builtins.attrNames secret.headers) (
              builtins.attrValues resource.secretFiles
            );
          in
          (resource.transport.type != "remote" && secretHeaderNames != [ ])
          || lib.unique secretHeaderNames != secretHeaderNames
          || (
            resource.transport.type == "remote"
            && lib.intersectLists (builtins.attrNames resource.transport.headers) secretHeaderNames != [ ]
          )
        ) enabledMcps
      );

      renderContribution =
        contribution:
        (
          if contribution.transport.type == "local" then
            {
              command = contribution.transport.command;
              args = contribution.transport.arguments;
            }
          else
            {
              url = contribution.transport.url;
            }
            // lib.optionalAttrs (contribution.transport.headers != { }) {
              inherit (contribution.transport) headers;
            }
        )
        // {
          inherit (contribution) lifecycle;
        };

      renderedServers =
        assert lib.assertMsg (duplicateServerIds == [ ])
          "MCP server IDs must be globally unique; collisions: ${lib.concatStringsSep ", " duplicateServerIds}";
        assert lib.assertMsg (conflictingEnvironmentNames == [ ])
          "MCP Pi-process environment declarations conflict: ${lib.concatStringsSep ", " conflictingEnvironmentNames}";
        builtins.listToAttrs (
          map (
            contribution: lib.nameValuePair contribution.serverId (renderContribution contribution)
          ) contributions
        );
    in
    {
      options = {
        dendriticSlop.mcps = mcpOptions;
        dendriticSlopInternal.mcp.servers = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule serverContributionModule);
          default = [ ];
          internal = true;
          description = "Typed mergeable MCP server contributions consumed by the single MCP renderer.";
        };
      };

      config = lib.mkIf config.dendriticSlop.enable {
        dendriticSlopInternal.mcp.servers = selectedContributions;

        assertions = [
          {
            assertion = duplicateServerIds == [ ];
            message = "MCP server IDs must be globally unique; collisions: ${lib.concatStringsSep ", " duplicateServerIds}";
          }
          {
            assertion = conflictingEnvironmentNames == [ ];
            message = "MCP Pi-process environment declarations conflict: ${lib.concatStringsSep ", " conflictingEnvironmentNames}";
          }
          {
            assertion = invalidSecretHeaderMcps == [ ];
            message = "MCP secret-backed headers must be unique and are valid only for remote transports: ${lib.concatStringsSep ", " invalidSecretHeaderMcps}";
          }
          {
            assertion = !hasPiProcessSecrets || unsafeExtensionNames == [ ];
            message = ''
              MCP runtime secrets are exposed to the Pi process, but these selected extensions are not reviewed as secret-capable: ${lib.concatStringsSep ", " unsafeExtensionNames}
            '';
          }
        ];

        programs.pi.coding-agent.environment = piProcessEnvironment;

        xdg.configFile."mcp/mcp.json" = lib.mkIf (contributions != [ ]) {
          text = builtins.toJSON { mcpServers = renderedServers; };
        };
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.mcp.imports = [
    resourcesModule
    targetModule
  ];
}
