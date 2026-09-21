{
  config,
  inputs,
  lib,
  pkgs,
  system,
}:
rec {
  inherit
    config
    inputs
    lib
    pkgs
    system
    ;
  testUser = "slop-test";
  catalog = config.dendriticSlopInternal.catalog;
  realizedSkills = config.dendriticSlopInternal.realized.skills pkgs;
  realizedHerdrPlugins = config.dendriticSlopInternal.realized.herdrPlugins pkgs;
  profilePackages = config.dendriticSlopInternal.realized.profiles pkgs;
  catalogType = config.dendriticSlopInternal.resourceSchema.catalogType;
  inherit (config.flake.lib)
    realizeHerdrPlugins
    realizePiPackages
    realizeProfile
    resourceAssertions
    resourceKinds
    ;
  # Synthetic fixtures exercise the same invariant checker used by Home Manager.
  validSelection =
    catalog': requested:
    lib.all (check: check.assertion) (resourceAssertions {
      catalog = catalog';
      inherit pkgs;
      selectedTargets = [
        "git"
        "herdr"
        "pi"
        "rules"
      ];
      selected = lib.genAttrs resourceKinds (
        kind: lib.filterAttrs (name: _: requested.${kind}.${name} or false) catalog'.${kind}
      );
    });

  tryCatalog =
    value:
    builtins.tryEval (
      let
        evaluated =
          (lib.evalModules {
            modules = [
              {
                options.fixture = lib.mkOption { type = catalogType; };
                config.fixture = value;
              }
            ];
          }).config.fixture;
      in
      builtins.deepSeq evaluated evaluated
    );

  catalogEvaluation = builtins.tryEval (builtins.deepSeq catalog catalog);
  invalidMcpVariant = tryCatalog {
    mcps.invalid = {
      title = "Invalid MCP";
      description = "Schema fixture with mixed remote and local fields.";
      transport = {
        type = "remote";
        url = "https://example.invalid/mcp";
        executable = "invalid";
      };
    };
  };
  invalidExtensionVariant = tryCatalog {
    extensions.invalid = {
      title = "Invalid extension";
      description = "Schema fixture with mixed path and package fields.";
      realization = {
        type = "path";
        source = ./fixtures.nix;
        destination = ".pi/agent/extensions/invalid.ts";
        package = _: pkgs.hello;
      };
    };
  };

  duplicateCatalog = catalog // {
    skills = catalog.skills // {
      duplicate-bro = catalog.skills.bro // {
        name = "duplicate-bro";
        profiles = [ ];
      };
    };
  };
  duplicateExposedName = validSelection duplicateCatalog {
    skills = {
      bro = true;
      duplicate-bro = true;
    };
  };
  duplicateMcpCatalog = catalog // {
    mcps = catalog.mcps // {
      duplicate-context7 = catalog.mcps.context7 // {
        name = "duplicate-context7";
        profiles = [ ];
      };
    };
  };
  duplicateMcpId = validSelection duplicateMcpCatalog {
    mcps = {
      context7 = true;
      duplicate-context7 = true;
    };
  };
  basePlugin = catalog.herdrPlugins.jj-workspace;
  distinctPlugin =
    overrides:
    basePlugin
    // {
      name = "fixture-plugin";
      profiles = [ ];
      pluginId = "fixture.plugin";
      executable = "fixture-plugin";
      source = ./fixtures.nix;
      keybindings = [
        {
          key = "prefix+fixture";
          command = "fixture.plugin.run";
          description = "Fixture";
        }
      ];
    }
    // overrides;
  pluginCollision =
    duplicate:
    let
      fixtureCatalog = catalog // {
        herdrPlugins = catalog.herdrPlugins // {
          fixture-plugin = duplicate;
        };
      };
    in
    validSelection fixtureCatalog {
      herdrPlugins = {
        jj-workspace = true;
        fixture-plugin = true;
      };
    };
  duplicatePluginSource = pluginCollision (distinctPlugin {
    source = basePlugin.source;
  });
  duplicatePluginId = pluginCollision (distinctPlugin {
    pluginId = basePlugin.pluginId;
  });
  duplicatePluginExecutable = pluginCollision (distinctPlugin {
    executable = basePlugin.executable;
  });
  duplicatePluginKey = pluginCollision (distinctPlugin {
    keybindings = [
      {
        key = (builtins.head basePlugin.keybindings).key;
        command = "fixture.plugin.run";
        description = "Fixture";
      }
    ];
  });
  pluginVersionMismatch = builtins.tryEval (
    let
      plugins = {
        fixture = basePlugin // {
          package =
            pkgs':
            (basePlugin.package pkgs').overrideAttrs (_: {
              version = "999.0.0";
              __intentionallyOverridingVersion = true;
            });
        };
      };
      realized = realizeHerdrPlugins { inherit pkgs plugins; };
    in
    realized.fixture.root.drvPath
  );
  pluginPackageWithoutVersion = builtins.tryEval (
    let
      plugins = {
        fixture = basePlugin // {
          package =
            pkgs':
            pkgs'.runCommand "versionless-herdr-plugin-fixture" { } ''
              mkdir -p "$out/bin"
            '';
        };
      };
      realized = realizeHerdrPlugins { inherit pkgs plugins; };
    in
    realized.fixture.root.drvPath
  );
  executableCollisionCatalog = catalog // {
    profiles = catalog.profiles // {
      executable-collision = {
        name = "executable-collision";
        title = "Executable collision";
        description = "Collision fixture.";
        targets = [ ];
        members = {
          skills = [ ];
          mcps = [ ];
          extensions = [ ];
          tools = [
            "herdr"
            "second-herdr"
          ];
          herdrPlugins = [ ];
        };
      };
    };
    tools = catalog.tools // {
      second-herdr = catalog.tools.herdr // {
        name = "second-herdr";
        package = pkgs': pkgs'.writeShellScriptBin "herdr" "exit 0";
        profiles = [ "executable-collision" ];
        requiresTargets = [ ];
        sourceVersion = null;
      };
    };
  };
  profileExecutableCollision = builtins.tryEval (
    let
      realized = realizeProfile {
        catalog = executableCollisionCatalog;
        inherit
          pkgs
          realizedHerdrPlugins
          realizedSkills
          ;
        profileName = "executable-collision";
        realizedExtensions = config.dendriticSlopInternal.realized.extensions pkgs;
      };
    in
    builtins.deepSeq realized realized
  );
  unsupportedSystem = if system == "x86_64-linux" then "aarch64-darwin" else "x86_64-linux";
  unsupportedCatalog = catalog // {
    skills = catalog.skills // {
      unsupported-runtime = catalog.skills.coding-guidelines // {
        name = "unsupported-runtime";
        exposedName = "unsupported-runtime";
        profiles = [ ];
        runtimePackages = _: [
          (pkgs.hello.overrideAttrs (_: {
            meta.platforms = [ unsupportedSystem ];
          }))
        ];
      };
    };
  };
  unsupportedPackage = validSelection unsupportedCatalog { skills.unsupported-runtime = true; };

  mkHomeModules =
    modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          dendriticSlop.enable = true;
          home = {
            username = testUser;
            homeDirectory =
              if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${testUser}" else "/home/${testUser}";
            stateVersion = "25.11";
          };
        }
      ]
      ++ modules;
    };
  mkHome =
    extraModule:
    mkHomeModules [
      config.flake.modules.homeManager.slop
      extraModule
    ];
  homeWithStandaloneMcp = mkHomeModules [
    config.flake.modules.homeManager.mcp
    {
      dendriticSlop = {
        mcps.linear.enable = true;
        extensions.pi-mcp-adapter.enable = true;
      };
    }
  ];

  tryHome =
    extraModule:
    builtins.tryEval (
      let
        evaluated = mkHome extraModule;
      in
      builtins.deepSeq evaluated.activationPackage evaluated.activationPackage
    );

  homeWithStandalonePi = mkHome { dendriticSlop.tools.pi.enable = true; };
  homeWithMissingAdapter = tryHome { dendriticSlop.mcps.linear.enable = true; };
  homeWithDisabledHerdr = tryHome {
    dendriticSlop = {
      profiles.core.enable = true;
      targets.herdr.enable = false;
    };
  };
  homeWithStandaloneSkill = mkHome { dendriticSlop.skills.bro.enable = true; };

  tryContext7Secret =
    value:
    builtins.tryEval (
      let
        evaluated = mkHome {
          dendriticSlop.mcps.context7.secrets.apiKeyFile = value;
        };
        secret = evaluated.config.dendriticSlop.mcps.context7.secrets.apiKeyFile;
      in
      builtins.deepSeq secret secret
    );

  context7SecretPath = "/run/agenix/context7-api-key";
  home = mkHome { };
  homeWithOnlyLinear = mkHome {
    dendriticSlop = {
      mcps.linear.enable = true;
      extensions.pi-mcp-adapter.enable = true;
    };
  };
  linearMcpJson = builtins.fromJSON homeWithOnlyLinear.config.xdg.configFile."mcp/mcp.json".text;
  homeWithContext7 = mkHome {
    dendriticSlop = {
      profiles.core.enable = true;
      mcps.context7 = {
        enable = true;
        secrets.apiKeyFile = context7SecretPath;
      };
    };
  };
  homeWithContext7NoSecret = mkHome {
    dendriticSlop = {
      profiles.core.enable = true;
      mcps.context7.enable = true;
    };
  };
  homeWithMergedMcps = mkHome {
    dendriticSlop = {
      profiles = {
        core.enable = true;
        web.enable = true;
      };
      mcps.linear.enable = true;
      mcps.context7 = {
        enable = true;
        secrets.apiKeyFile = context7SecretPath;
      };
    };
  };
  homeWithRelativeSecret = tryContext7Secret "relative/context7-key";
  homeWithLiteralSecret = tryContext7Secret "literal-secret-value";
  homeWithNixPathSecret = tryContext7Secret ./fixtures.nix;
  homeWithStoreSecret = tryContext7Secret "${builtins.storeDir}/context7-key";
  homeWithUnsafeSecretExtension = tryHome {
    dendriticSlop = {
      profiles.core.enable = true;
      extensions.superpowers-bootstrap.enable = true;
      mcps.context7 = {
        enable = true;
        secrets.apiKeyFile = context7SecretPath;
      };
    };
  };
  homeWithMcpCollision = tryHome {
    dendriticSlopInternal.mcp.servers = [
      {
        owner = "fixture.first";
        serverId = "collision";
        transport = {
          type = "remote";
          url = "https://first.example.invalid/mcp";
        };
      }
      {
        owner = "fixture.second";
        serverId = "collision";
        transport = {
          type = "remote";
          url = "https://second.example.invalid/mcp";
        };
      }
    ];
  };
  homeWithProfiles = mkHome {
    dendriticSlop = {
      profiles = {
        core.enable = true;
        python.enable = true;
      };
      skills = {
        brainstorming.enable = true;
        bro.enable = false;
        ty.enable = false;
      };
      targets.git.enable = false;
    };
  };
  homeWithDisabledPi = builtins.tryEval (
    let
      evaluated = mkHome {
        dendriticSlop = {
          profiles.core.enable = true;
          targets.pi.enable = false;
        };
      };
    in
    builtins.deepSeq evaluated.activationPackage evaluated.activationPackage
  );
  homeWithWebAccess = mkHome {
    dendriticSlop.extensions.web-access.enable = true;
  };
  homeWithAllExtensions = mkHome {
    dendriticSlop.extensions = lib.genAttrs (builtins.attrNames catalog.extensions) (_: {
      enable = true;
    });
  };
  homeWithJjWorkspace = mkHome {
    dendriticSlop = {
      herdr.plugins.jj-workspace.enable = true;
      targets.herdr.enable = true;
    };
  };
  jjWorkspaceResource = catalog.herdrPlugins.jj-workspace;
  jjWorkspacePackage = realizedHerdrPlugins.jj-workspace.package;
  jjWorkspaceRoot = realizedHerdrPlugins.jj-workspace.root;
  defaultJjWorkspaceActivation = home.config.home.activation.dendriticSlopHerdrPlugins.data;
  jjWorkspaceActivation = homeWithJjWorkspace.config.home.activation.dendriticSlopHerdrPlugins.data;
  defaultHerdrManageScript = home.config.dendriticSlopInternal.herdr.manageScript;
  enabledHerdrManageScript = homeWithJjWorkspace.config.dendriticSlopInternal.herdr.manageScript;
  jjWorkspaceManifest = pkgs.runCommand "herdr-plugin-jj-workspace-manifest-check" { } ''
    test -x ${jjWorkspaceRoot}/target/release/jj-workspace
    ${pkgs.gnugrep}/bin/grep -Fqx 'id = "nathanflurry.jj-workspace"' ${jjWorkspaceRoot}/herdr-plugin.toml
    ${pkgs.gnugrep}/bin/grep -Fqx 'id = "new"' ${jjWorkspaceRoot}/herdr-plugin.toml
    ${pkgs.gnugrep}/bin/grep -Fqx 'id = "new-tab"' ${jjWorkspaceRoot}/herdr-plugin.toml
    ${pkgs.gnugrep}/bin/grep -Fqx 'id = "remove"' ${jjWorkspaceRoot}/herdr-plugin.toml
    touch "$out"
  '';
  herdrAgentStateResource = catalog.extensions.herdr-agent-state;
  managedHerdrAgentState =
    homeWithProfiles.config.home.file.".pi/agent/extensions/herdr-agent-state.ts";
  managedSkills = home.config.home.file.".agents/skills";
  realizedExtensions = config.dendriticSlopInternal.realized.extensions pkgs;
  extensionPackages = builtins.listToAttrs (
    map (entry: lib.nameValuePair entry.name entry.package) realizedExtensions.packageEntries
  );
  piPackage = catalog.tools.pi.package pkgs;
  finalPiPackage = homeWithProfiles.config.programs.pi.coding-agent.finalPackage;
  herdrPackage = catalog.tools.herdr.package pkgs;
  webAccessPackage = toString extensionPackages.web-access;
  agentBrowserPackage = catalog.mcps.browser.transport.package pkgs;
  agentBrowserCommand = lib.getExe' agentBrowserPackage catalog.mcps.browser.transport.executable;
  mergedMcpJson = builtins.fromJSON (
    builtins.unsafeDiscardStringContext homeWithMergedMcps.config.xdg.configFile."mcp/mcp.json".text
  );
  expectedMergedMcpJson = {
    mcpServers = {
      agent-browser = {
        args = [ "mcp" ];
        command = agentBrowserCommand;
        lifecycle = "lazy";
      };
      context7 = {
        headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
        lifecycle = "lazy";
        url = "https://mcp.context7.com/mcp";
      };
      linear = {
        auth = "oauth";
        lifecycle = "lazy";
        url = "https://mcp.linear.app/mcp";
      };
    };
  };
  defaultPackages = home.config.programs.pi.coding-agent.settings.packages;
  corePackages = homeWithProfiles.config.programs.pi.coding-agent.settings.packages;
  optedInPackages = homeWithWebAccess.config.programs.pi.coding-agent.settings.packages;
  allExtensionPackages = homeWithAllExtensions.config.programs.pi.coding-agent.settings.packages;
  duplicatePiPackage = realizePiPackages {
    inherit pkgs;
    extensions = {
      first = catalog.extensions.ask-user;
      second = catalog.extensions.ask-user;
    };
  };
  conflictingPiPackage = builtins.tryEval (
    let
      realized = realizePiPackages {
        inherit pkgs;
        extensions = {
          first = catalog.extensions.ask-user;
          second = catalog.extensions.ask-user // {
            realization = catalog.extensions.ask-user.realization // {
              version = "999.0.0";
            };
          };
        };
      };
    in
    builtins.deepSeq realized realized
  );
  mcpSecretServer = pkgs.replaceVars ./probes/mcp-secret-server.mjs {
    adapterRoot = extensionPackages.pi-mcp-adapter;
  };
  mcpSecretProbe = pkgs.replaceVars ./probes/mcp-secret.ts {
    adapterRoot = extensionPackages.pi-mcp-adapter;
    node = lib.getExe pkgs.nodejs_24;
    server = mcpSecretServer;
  };
  piResourceProbe = pkgs.replaceVars ./probes/pi-resources.ts {
    expectedTools = builtins.toJSON {
      ask_user = toString extensionPackages.ask-user;
      fetch_content = toString extensionPackages.web-access;
      get_search_content = toString extensionPackages.web-access;
      goal_complete = toString extensionPackages.pi-goal;
      goal_blocked = toString extensionPackages.pi-goal;
      goal_wait = toString extensionPackages.pi-goal;
      jevons_decide = toString extensionPackages.jevons;
      jevons_review = toString extensionPackages.jevons;
      mcp = toString extensionPackages.pi-mcp-adapter;
      mcpScript = toString extensionPackages.pi-mcp-adapter;
      source_check = toString extensionPackages.web-access;
      web_search = toString extensionPackages.web-access;
    };
  };
  piDependencyContractProbe = ./probes/package-peers.mjs;

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

  mkBridgeSystem =
    hostSelection: homeDefaults:
    let
      hostModule = {
        dendriticSlop = {
          enable = true;
          username = testUser;
        }
        // hostSelection;
        home-manager.users.${testUser} = {
          dendriticSlop = homeDefaults;
          home.stateVersion = "25.11";
        };
      };
    in
    if pkgs.stdenv.hostPlatform.isDarwin then
      inputs.nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          inputs.home-manager.darwinModules.home-manager
          config.flake.modules.darwin.slop
          hostModule
          {
            system.stateVersion = 6;
            users.users.${testUser}.home = "/Users/${testUser}";
          }
        ];
      }
    else
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.impermanence.nixosModules.impermanence
          config.flake.modules.nixos.slop
          hostModule
          {
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
            system.stateVersion = "25.11";
            users.users.${testUser}.isNormalUser = true;
          }
        ];
      };
  bridgeHome = host: host.config.home-manager.users.${testUser}.dendriticSlop;
  bridgeUnset = bridgeHome (
    mkBridgeSystem { } {
      profiles.core.enable = lib.mkDefault true;
      skills.ty.enable = lib.mkDefault true;
    }
  );
  bridgeTrue = bridgeHome (
    mkBridgeSystem
      {
        profiles.core.enable = true;
        skills.ty.enable = true;
        mcps.context7 = {
          enable = true;
          secrets.apiKeyFile = context7SecretPath;
        };
      }
      {
        profiles.core.enable = lib.mkDefault false;
        skills.ty.enable = lib.mkDefault false;
        mcps.context7.enable = lib.mkDefault false;
      }
  );
  bridgeFalse = bridgeHome (
    mkBridgeSystem
      {
        profiles.core.enable = false;
        skills.ty.enable = false;
        mcps.context7.enable = false;
      }
      {
        profiles.core.enable = lib.mkDefault true;
        skills.ty.enable = lib.mkDefault true;
        mcps.context7.enable = lib.mkDefault true;
      }
  );

  allSkills = realizedSkills.tree;
}
