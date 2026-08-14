{ lib, ... }:
let
  inherit (lib) mkOption types;

  nonEmptyString = types.addCheck types.str (value: value != "");
  resourceName = types.addCheck nonEmptyString (
    value: builtins.match "[a-z0-9]+(-[a-z0-9]+)*" value != null
  );
  resourceReference = types.addCheck nonEmptyString (
    value:
    builtins.match "(skills|mcps|extensions|tools|herdrPlugins)\\.[a-z0-9]+(-[a-z0-9]+)*" value != null
  );
  systemName = types.addCheck nonEmptyString (
    value: builtins.match "[a-z0-9_]+-[a-z0-9_]+" value != null
  );
  packageFunction = types.functionTo types.raw;

  capabilityModule = {
    options = {
      executesCode = mkOption {
        type = types.bool;
        default = false;
      };
      mutatesUserConfig = mkOption {
        type = types.bool;
        default = false;
      };
      network = mkOption {
        type = types.bool;
        default = false;
      };
      readsSecrets = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  commonMetadataModule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = resourceName;
          default = name;
          readOnly = true;
        };
        title = mkOption { type = nonEmptyString; };
        description = mkOption { type = nonEmptyString; };
        homepage = mkOption {
          type = types.nullOr nonEmptyString;
          default = null;
        };
        repository = mkOption {
          type = types.nullOr resourceName;
          default = null;
        };
        profiles = mkOption {
          type = types.listOf resourceName;
          default = [ ];
        };
        platforms = mkOption {
          type = types.nullOr (types.listOf systemName);
          default = null;
        };
        defaultEnable = mkOption {
          type = types.bool;
          default = false;
        };
        capabilities = mkOption {
          type = types.submodule capabilityModule;
          default = { };
        };
        requiresTargets = mkOption {
          type = types.listOf resourceName;
          default = [ ];
        };
        requiresResources = mkOption {
          type = types.listOf resourceReference;
          default = [ ];
        };
      };
    };

  runtimeExecutableModule = {
    options = {
      package = mkOption { type = packageFunction; };
      executable = mkOption { type = nonEmptyString; };
    };
  };

  skillModule =
    { config, ... }:
    {
      imports = [ commonMetadataModule ];
      options = {
        exposedName = mkOption {
          type = resourceName;
          default = config.name;
        };
        repositoryPath = mkOption {
          type = types.nullOr nonEmptyString;
          default = null;
        };
        source = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
        runtimePackages = mkOption {
          type = packageFunction;
          default = _: [ ];
        };
        runtimeExecutables = mkOption {
          type = types.listOf (types.submodule runtimeExecutableModule);
          default = [ ];
        };
        requiresHarnessCapabilities = mkOption {
          type = types.listOf nonEmptyString;
          default = [ ];
        };
        compatibilityTargets = mkOption {
          type = types.listOf resourceName;
          default = [ ];
        };
      };
    };

  localMcpTransportModule = {
    options = {
      type = mkOption { type = types.enum [ "local" ]; };
      package = mkOption { type = packageFunction; };
      executable = mkOption { type = nonEmptyString; };
      arguments = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };

  remoteMcpTransportModule = {
    options = {
      type = mkOption { type = types.enum [ "remote" ]; };
      url = mkOption { type = nonEmptyString; };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
    };
  };

  taggedSubmodule =
    tag: module: types.addCheck (types.submodule module) (value: (value.type or null) == tag);

  mcpTransportType = types.oneOf [
    (taggedSubmodule "local" localMcpTransportModule)
    (taggedSubmodule "remote" remoteMcpTransportModule)
  ];

  secretFileModule = {
    options = {
      description = mkOption { type = nonEmptyString; };
      environment = mkOption { type = nonEmptyString; };
    };
  };

  mcpModule =
    { config, ... }:
    {
      imports = [ commonMetadataModule ];
      options = {
        serverId = mkOption {
          type = nonEmptyString;
          default = config.name;
        };
        transport = mkOption { type = mcpTransportType; };
        lifecycle = mkOption {
          type = types.enum [
            "persistent"
            "on-demand"
          ];
          default = "on-demand";
        };
        environmentNames = mkOption {
          type = types.listOf nonEmptyString;
          default = [ ];
        };
        secretFiles = mkOption {
          type = types.attrsOf (types.submodule secretFileModule);
          default = { };
        };
      };
    };

  pathExtensionRealizationModule = {
    options = {
      type = mkOption { type = types.enum [ "path" ]; };
      source = mkOption { type = types.path; };
      destination = mkOption { type = nonEmptyString; };
    };
  };

  packageExtensionRealizationModule = {
    options = {
      type = mkOption { type = types.enum [ "package" ]; };
      package = mkOption { type = packageFunction; };
      packageId = mkOption { type = nonEmptyString; };
      version = mkOption {
        type = types.nullOr nonEmptyString;
        default = null;
      };
    };
  };

  extensionRealizationType = types.oneOf [
    (taggedSubmodule "path" pathExtensionRealizationModule)
    (taggedSubmodule "package" packageExtensionRealizationModule)
  ];

  environmentModule = {
    options = {
      value = mkOption { type = types.str; };
      sensitive = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  extensionModule = {
    imports = [ commonMetadataModule ];
    options = {
      realization = mkOption { type = extensionRealizationType; };
      environment = mkOption {
        type = types.attrsOf (types.submodule environmentModule);
        default = { };
      };
      secretCapable = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  toolModule = {
    imports = [ commonMetadataModule ];
    options = {
      package = mkOption { type = packageFunction; };
      executable = mkOption { type = nonEmptyString; };
    };
  };

  keybindingModule = {
    options = {
      key = mkOption { type = nonEmptyString; };
      command = mkOption { type = nonEmptyString; };
      description = mkOption { type = nonEmptyString; };
    };
  };

  herdrPluginModule = {
    imports = [ commonMetadataModule ];
    options = {
      package = mkOption { type = packageFunction; };
      pluginRoot = mkOption { type = packageFunction; };
      pluginId = mkOption { type = nonEmptyString; };
      version = mkOption { type = nonEmptyString; };
      minimumHerdrVersion = mkOption { type = nonEmptyString; };
      actions = mkOption {
        type = types.listOf nonEmptyString;
        default = [ ];
      };
      keybindings = mkOption {
        type = types.listOf (types.submodule keybindingModule);
        default = [ ];
      };
    };
  };

  repositoryEntrypointModule = {
    options = {
      path = mkOption { type = nonEmptyString; };
      type = mkOption {
        type = types.enum [
          "executable"
          "interpreter"
        ];
      };
      interpreter = mkOption {
        type = types.nullOr nonEmptyString;
        default = null;
      };
      owner = mkOption {
        type = types.nullOr resourceName;
        default = null;
      };
    };
  };

  repositoryModule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = resourceName;
          default = name;
          readOnly = true;
        };
        input = mkOption { type = resourceName; };
        source = mkOption { type = types.path; };
        homepage = mkOption { type = nonEmptyString; };
        license = mkOption { type = nonEmptyString; };
        licenseEvidence = mkOption { type = types.listOf types.path; };
        exportedLeaves = mkOption {
          type = types.listOf resourceName;
          default = [ ];
        };
        ignoredLeaves = mkOption {
          type = types.listOf resourceName;
          default = [ ];
        };
        supportPaths = mkOption {
          type = types.listOf nonEmptyString;
          default = [ ];
        };
        entrypoints = mkOption {
          type = types.listOf (types.submodule repositoryEntrypointModule);
          default = [ ];
        };
        ignoredEntrypoints = mkOption {
          type = types.listOf nonEmptyString;
          default = [ ];
        };
        patches = mkOption {
          type = types.listOf types.path;
          default = [ ];
        };
        buildInputs = mkOption {
          type = types.listOf packageFunction;
          default = [ ];
        };
        reviewedRevision = mkOption {
          type = types.nullOr nonEmptyString;
          default = null;
        };
      };
    };

  profileMembersModule = {
    options = {
      skills = mkOption {
        type = types.listOf resourceName;
        default = [ ];
      };
      mcps = mkOption {
        type = types.listOf resourceName;
        default = [ ];
      };
      extensions = mkOption {
        type = types.listOf resourceName;
        default = [ ];
      };
      tools = mkOption {
        type = types.listOf resourceName;
        default = [ ];
      };
      herdrPlugins = mkOption {
        type = types.listOf resourceName;
        default = [ ];
      };
    };
  };

  profileModule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = resourceName;
          default = name;
          readOnly = true;
        };
        title = mkOption { type = nonEmptyString; };
        description = mkOption { type = nonEmptyString; };
        targets = mkOption {
          type = types.listOf resourceName;
          default = [ ];
        };
        members = mkOption {
          type = types.submodule profileMembersModule;
          default = { };
        };
      };
    };

  catalogModule = {
    options = {
      repositories = mkOption {
        type = types.attrsOf (types.submodule repositoryModule);
        default = { };
      };
      profiles = mkOption {
        type = types.attrsOf (types.submodule profileModule);
        default = { };
      };
      skills = mkOption {
        type = types.attrsOf (types.submodule skillModule);
        default = { };
      };
      mcps = mkOption {
        type = types.attrsOf (types.submodule mcpModule);
        default = { };
      };
      extensions = mkOption {
        type = types.attrsOf (types.submodule extensionModule);
        default = { };
      };
      tools = mkOption {
        type = types.attrsOf (types.submodule toolModule);
        default = { };
      };
      herdrPlugins = mkOption {
        type = types.attrsOf (types.submodule herdrPluginModule);
        default = { };
      };
    };
  };
in
{
  options.dendriticSlopInternal.resourceSchema = mkOption {
    type = types.raw;
    readOnly = true;
    internal = true;
  };

  config.dendriticSlopInternal.resourceSchema = {
    inherit
      catalogModule
      commonMetadataModule
      extensionModule
      herdrPluginModule
      mcpModule
      profileModule
      repositoryModule
      skillModule
      toolModule
      ;
    catalogType = types.submodule catalogModule;
  };
}
