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
            source = ./checks.nix;
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
          source = ./checks.nix;
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
                homeDirectory =
                  if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${testUser}" else "/home/${testUser}";
                stateVersion = "25.11";
              };
            }
            extraModule
          ];
        };

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
      homeWithNixPathSecret = tryContext7Secret ./checks.nix;
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
      mcpSecretServer = pkgs.writeText "dendritic-slop-mcp-secret-server.mjs" ''
        import { Server } from "${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/sdk/dist/esm/server/index.js";
        import { StdioServerTransport } from "${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/sdk/dist/esm/server/stdio.js";
        import { CallToolRequestSchema, ListToolsRequestSchema } from "${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/sdk/dist/esm/types.js";

        const server = new Server(
          { name: "dendritic-secret-fixture", version: "1.0.0" },
          { capabilities: { tools: {} } },
        );
        server.setRequestHandler(ListToolsRequestSchema, async () => ({
          tools: [{
            name: "read_secret",
            description: "Return the child-scoped fake secret.",
            inputSchema: { type: "object", properties: {} },
          }],
        }));
        server.setRequestHandler(CallToolRequestSchema, async () => ({
          content: [{ type: "text", text: process.env.FAKE_SECRET ?? "" }],
        }));
        await server.connect(new StdioServerTransport());
      '';
      mcpSecretProbe = pkgs.writeText "dendritic-slop-mcp-secret-probe.ts" ''
        import { writeFileSync } from "node:fs";
        import { createMcpAdapter } from "${extensionPackages.pi-mcp-adapter}/index.ts";

        export default function (pi: any) {
          const registeredTools = new Map<string, any>();
          const adapterApi = new Proxy(pi, {
            get(target, property) {
              if (property === "registerTool") {
                return (tool: any) => {
                  registeredTools.set(tool.name, tool);
                  return target.registerTool(tool);
                };
              }
              const value = target[property];
              return typeof value === "function" ? value.bind(target) : value;
            },
          });

          createMcpAdapter({
            config: {
              mcpServers: {
                secret: {
                  command: "${lib.getExe pkgs.nodejs_24}",
                  args: ["${mcpSecretServer}"],
                  env: { FAKE_SECRET: "''${CONTEXT7_API_KEY}" },
                  lifecycle: "lazy",
                },
              },
            },
          })(adapterApi);

          pi.registerCommand("dendritic-mcp-secret-smoke", {
            handler: async (_args: string, ctx: any) => {
              const proxy = registeredTools.get("mcp");
              if (!proxy) throw new Error("MCP proxy tool was not registered");
              const result = await proxy.execute(
                "dendritic-secret-smoke",
                { tool: "secret_read_secret" },
                undefined,
                undefined,
                ctx,
              );
              const text = result.content
                .filter((block: any) => block.type === "text")
                .map((block: any) => block.text)
                .join("\n");
              const expected = process.env.CONTEXT7_API_KEY;
              if (!expected || !text.includes(expected)) {
                throw new Error("MCP adapter did not interpolate the fake Pi-process secret into the child environment");
              }
              writeFileSync(process.env.DENDRITIC_SLOP_MCP_SECRET_MARKER!, "invoked\n");
            },
          });
        }
      '';
      piResourceProbe = pkgs.writeText "dendritic-slop-pi-resource-probe.ts" ''
        import { writeFileSync } from "node:fs";

        export default function (pi: any) {
          pi.registerCommand("dendritic-offline-smoke", {
            handler: async (_args: string, ctx: any) => {
              const tools = new Map(pi.getAllTools().map((tool: any) => [tool.name, tool]));
              const expected = ${
                builtins.toJSON {
                  ask_user = toString extensionPackages.ask-user;
                  fetch_content = toString extensionPackages.web-access;
                  get_search_content = toString extensionPackages.web-access;
                  jevons_decide = toString extensionPackages.jevons;
                  jevons_review = toString extensionPackages.jevons;
                  mcp = toString extensionPackages.pi-mcp-adapter;
                  mcpScript = toString extensionPackages.pi-mcp-adapter;
                  source_check = toString extensionPackages.web-access;
                  web_search = toString extensionPackages.web-access;
                }
              };
              for (const [name, root] of Object.entries(expected)) {
                const tool: any = tools.get(name);
                if (!tool) throw new Error(`missing tool: ''${name}`);
                if (!tool.sourceInfo?.path?.startsWith(root as string)) {
                  throw new Error(`wrong source for ''${name}: ''${tool.sourceInfo?.path}`);
                }
              }
              if (!pi.getCommands().some((command: any) => command.name === "mcp")) {
                throw new Error("missing MCP command");
              }
              writeFileSync(process.env.DENDRITIC_SLOP_SMOKE_MARKER!, "loaded\n");
              ctx.shutdown();
            },
          });
        }
      '';
      piDependencyContractProbe = pkgs.writeText "dendritic-slop-pi-dependency-contract.mjs" ''
        import { existsSync, readFileSync } from "node:fs";
        import { join } from "node:path";

        const [root, expectedPeersJson] = process.argv.slice(2);
        const manifest = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
        const expectedPeers = JSON.parse(expectedPeersJson);
        const dependencies = manifest.dependencies ?? {};
        const peers = manifest.peerDependencies ?? {};
        const peerMeta = manifest.peerDependenciesMeta ?? {};

        for (const name of Object.keys(expectedPeers)) {
          if (peers[name] !== "*") throw new Error("non-wildcard Pi host peer: " + name);
          if (peerMeta[name]?.optional !== true) throw new Error("non-optional Pi host peer: " + name);
          if (name in dependencies) throw new Error("Pi host peer bundled as dependency: " + name);
          if (existsSync(join(root, "node_modules", ...name.split("/")))) {
            throw new Error("Pi host peer present in installed closure: " + name);
          }
        }

      '';

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
    in
    {
      checks = {
        profile-selection =
          assert !(home.options.dendriticSlop ? autoEnable);
          assert !builtins.hasAttr "actionbook-rust" home.options.dendriticSlop.skills;
          assert !builtins.hasAttr "astral-python" home.options.dendriticSlop.skills;
          assert !builtins.hasAttr "superpowers" home.options.dendriticSlop.skills;
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
          assert homeWithProfiles.config.dendriticSlop.skills.brainstorming.enable;
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
        skill-projections =
          let
            actionbookRepository = catalog.repositories.actionbook-rust;
            astralRepository = catalog.repositories.astral-python;
            leonardoRepository = catalog.repositories.leonardomso-rust-skills;
            ponytailRepository = catalog.repositories.ponytail;
            superpowersRepository = catalog.repositories.superpowers;
            actionbookUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (actionbookRepository.source + "/skills")
              )
            );
            astralUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (astralRepository.source + "/plugins/astral/skills")
              )
            );
            ponytailUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (ponytailRepository.source + "/skills")
              )
            );
            superpowersUpstreamLeaves = builtins.attrNames (
              lib.filterAttrs (_: type: type == "directory") (
                builtins.readDir (superpowersRepository.source + "/skills")
              )
            );
            reviewedEntrypoints = [
              ".pi/extensions/superpowers.ts"
              "skills/brainstorming/scripts/helper.js"
              "skills/brainstorming/scripts/server.cjs"
              "skills/brainstorming/scripts/start-server.sh"
              "skills/brainstorming/scripts/stop-server.sh"
              "skills/subagent-driven-development/scripts/review-package"
              "skills/subagent-driven-development/scripts/sdd-workspace"
              "skills/subagent-driven-development/scripts/task-brief"
              "skills/systematic-debugging/find-polluter.sh"
            ];
            intentionallyOmittedEntrypoints = [
              "skills/writing-skills/render-graphs.js"
            ];
            executableEntrypoints = map (entrypoint: entrypoint.path) (
              lib.filter (entrypoint: entrypoint.type == "executable") superpowersRepository.entrypoints
            );
            actionbookProjection = realizedSkills.repositories.actionbook-rust;
            astralProjection = realizedSkills.repositories.astral-python;
            leonardoProjection = realizedSkills.repositories.leonardomso-rust-skills;
            ponytailProjection = realizedSkills.repositories.ponytail;
            superpowersProjection = realizedSkills.repositories.superpowers;
          in
          assert
            lib.sort builtins.lessThan (
              actionbookRepository.exportedLeaves ++ actionbookRepository.ignoredLeaves
            ) == actionbookUpstreamLeaves;
          assert
            actionbookRepository.ignoredLeaves == [
              "core-actionbook"
              "core-agent-browser"
              "core-dynamic-skills"
              "core-fix-skill-docs"
            ];
          assert lib.sort builtins.lessThan astralRepository.exportedLeaves == astralUpstreamLeaves;
          assert astralRepository.ignoredLeaves == [ ];
          assert lib.sort builtins.lessThan superpowersRepository.exportedLeaves == superpowersUpstreamLeaves;
          assert superpowersRepository.ignoredLeaves == [ ];
          assert leonardoRepository.exportedLeaves == [ "rust-skills" ];
          assert lib.sort builtins.lessThan ponytailRepository.exportedLeaves == ponytailUpstreamLeaves;
          assert ponytailRepository.ignoredLeaves == [ ];
          assert map (entrypoint: entrypoint.path) superpowersRepository.entrypoints == reviewedEntrypoints;
          assert superpowersRepository.ignoredEntrypoints == intentionallyOmittedEntrypoints;
          assert lib.all (
            entrypoint:
            entrypoint.owner != null
            && (
              (entrypoint.type == "executable" && entrypoint.interpreter == null)
              || (entrypoint.type == "interpreter" && entrypoint.interpreter != null)
            )
          ) superpowersRepository.entrypoints;
          assert builtins.all builtins.pathExists (
            actionbookRepository.licenseEvidence
            ++ astralRepository.licenseEvidence
            ++ leonardoRepository.licenseEvidence
            ++ ponytailRepository.licenseEvidence
            ++ superpowersRepository.licenseEvidence
          );
          pkgs.runCommand "skill-projections-check"
            {
              leafPackages = builtins.attrValues realizedSkills.packages;
            }
            ''
              set -euo pipefail
              export LC_ALL=C

              test "$(${pkgs.findutils}/bin/find ${allSkills} -mindepth 1 -maxdepth 1 -type l | wc -l | tr -d ' ')" -eq ${toString (builtins.length (builtins.attrNames catalog.skills))}
              ${lib.concatMapStringsSep "\n" (name: ''
                test "$(readlink ${allSkills}/${name})" = ${
                  lib.escapeShellArg (toString realizedSkills.targets.${name})
                }
                test -L ${realizedSkills.packages.${name}}/${name}
                test -f ${allSkills}/${name}/SKILL.md
                ${pkgs.gnugrep}/bin/grep -Fqx ${lib.escapeShellArg "name: ${name}"} ${allSkills}/${name}/SKILL.md
                ${pkgs.gnugrep}/bin/grep -Eq '^description:' ${allSkills}/${name}/SKILL.md
              '') (builtins.attrNames catalog.skills)}

              test -f ${allSkills}/rust-learner/../../agents/crate-researcher.md
              test -f ${allSkills}/rust-learner/../../agents/rust-changelog.md
              test -f ${allSkills}/rust-daily/../../agents/rust-daily-reporter.md
              test -f ${allSkills}/meta-cognition-parallel/../../agents/layer1-analyzer.md
              test -f ${allSkills}/rust-router/patterns/negotiation.md
              test -f ${allSkills}/unsafe-checker/rules/ffi-01-no-string-direct.md

              test -f ${allSkills}/writing-skills/../using-superpowers/references/codex-tools.md
              test -f ${allSkills}/subagent-driven-development/../requesting-code-review/code-reviewer.md
              test -f ${allSkills}/executing-plans/../using-superpowers/references/pi-tools.md
              test -f ${allSkills}/brainstorming/scripts/frame-template.html

              # Omission smoke test through the final leaf link: the helper and its
              # immutable-write workflow must both be absent from the installed skill.
              test ! -e ${allSkills}/writing-skills/render-graphs.js
              ! ${pkgs.gnugrep}/bin/grep -Fq 'render-graphs.js' ${allSkills}/writing-skills/SKILL.md
              ${pkgs.gnugrep}/bin/grep -Fq 'omitted from immutable installations' ${allSkills}/writing-skills/SKILL.md

              test -f ${superpowersRepository.source}/skills/writing-skills/render-graphs.js
              test ! -e ${superpowersProjection}/skills/writing-skills/render-graphs.js
              test -f ${superpowersProjection}/package.json
              test -f ${superpowersProjection}/.pi/extensions/superpowers.ts
              ! ${pkgs.gnugrep}/bin/grep -Fq 'resources_discover' ${superpowersProjection}/.pi/extensions/superpowers.ts
              ${pkgs.gnugrep}/bin/grep -Fq '## Pi tool mapping' ${superpowersProjection}/.pi/extensions/superpowers.ts

              test -f ${actionbookProjection}/metadata.json
              ${pkgs.gnugrep}/bin/grep -Eq '"license"[[:space:]]*:[[:space:]]*"MIT"' ${actionbookProjection}/metadata.json
              ${pkgs.gnugrep}/bin/grep -Fq 'MIT License' ${actionbookProjection}/README.md
              test -f ${astralProjection}/LICENSE-APACHE
              test -f ${astralProjection}/LICENSE-MIT
              test -f ${leonardoProjection}/LICENSE
              test -f ${ponytailProjection}/LICENSE
              test -f ${superpowersProjection}/LICENSE

              ${lib.concatMapStringsSep "\n" (path: ''
                test -x ${superpowersProjection}/${path}
                shebang=$(head -n 1 ${superpowersProjection}/${path})
                if ! printf '%s\n' "$shebang" | ${pkgs.gnugrep}/bin/grep -Eq '^#! ?/nix/store/'; then
                  echo "unpatched shebang: ${path}: $shebang" >&2
                  exit 1
                fi
              '') executableEntrypoints}
              ${lib.concatMapStringsSep "\n" (entrypoint: ''
                test -f ${superpowersProjection}/${entrypoint.path}
              '') (lib.filter (entrypoint: entrypoint.type == "interpreter") superpowersRepository.entrypoints)}

              brainstorm_wrapper=${superpowersProjection}/skills/brainstorming/scripts/start-server.sh
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.nodejs_24)} "$brainstorm_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gitMinimal)} "$brainstorm_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.graphviz)} "$brainstorm_wrapper"

              subagent_wrapper=${superpowersProjection}/skills/subagent-driven-development/scripts/review-package
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gawk)} "$subagent_wrapper"
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gitMinimal)} "$subagent_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.nodejs_24)} "$subagent_wrapper"

              debugging_wrapper=${superpowersProjection}/skills/systematic-debugging/find-polluter.sh
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.findutils)} "$debugging_wrapper"
              ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.nodejs_24)} "$debugging_wrapper"
              ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString pkgs.gitMinimal)} "$debugging_wrapper"

              test "$(${pkgs.findutils}/bin/find ${actionbookProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'README.md _meta agents metadata.json skills '
              test "$(${pkgs.findutils}/bin/find ${astralProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'LICENSE-APACHE LICENSE-MIT plugins '
              test "$(${pkgs.findutils}/bin/find ${leonardoProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = 'LICENSE SKILL.md rules '
              test "$(${pkgs.findutils}/bin/find ${superpowersProjection} -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = '.pi LICENSE package.json skills '

              for projection in ${actionbookProjection} ${astralProjection} ${leonardoProjection} ${superpowersProjection}; do
                test ! -e "$projection/setup.sh"
                test ! -e "$projection/hooks"
                test ! -e "$projection/.claude"
                test ! -e "$projection/.github"
              done
              touch "$out"
            '';
        pi-playwright-runtime =
          pkgs.runCommand "pi-playwright-runtime-check"
            {
              nativeBuildInputs = [ pkgs.nodejs_24 ];
              PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
              FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
            }
            ''
              export HOME="$TMPDIR"
              node --input-type=module <<'EOF'
              import assert from "node:assert/strict";
              import { createRequire } from "node:module";

              const require = createRequire("${extensionPackages.pi-playwright}/package.json");
              const manifest = require("./package.json");
              const version = require("playwright/package.json").version;
              assert.equal(manifest.dependencies.playwright, version);
              assert.equal(require("playwright-core/package.json").version, version);
              assert.equal(version, "${pkgs.playwright-driver.version}");

              const { chromium } = require("playwright");
              const browser = await chromium.launch({ headless: true });
              try {
                const page = await browser.newPage();
                await page.setContent('<title>Pi Playwright</title><input id="value"><button>Submit</button>');
                assert.equal(await page.title(), "Pi Playwright");
                await page.locator("#value").fill("compatible");
                await page.getByText("Submit").click();
                assert.equal(await page.locator("#value").evaluate(el => el.value), "compatible");
                assert.ok((await page.screenshot()).length > 0);
              } finally {
                await browser.close();
              }
              EOF
              touch "$out"
            '';

        declarative-pi-packages =
          assert defaultPackages == [ ];
          assert builtins.elem (toString extensionPackages.ask-user) corePackages;
          assert builtins.elem (toString extensionPackages.pi-mcp-adapter) corePackages;
          assert !home.config.dendriticSlop.extensions.jevons.enable;
          assert catalog.extensions.jevons.profiles == [ ];
          assert catalog.extensions.jevons.capabilities.network;
          assert catalog.extensions.jevons.capabilities.executesCode;
          assert catalog.extensions.jevons.capabilities.readsSecrets;
          assert lib.all (lib.hasPrefix builtins.storeDir) allExtensionPackages;
          assert !lib.any (lib.hasPrefix "npm:") allExtensionPackages;
          assert homeWithProfiles.config.programs.pi.coding-agent.package == piPackage;
          assert finalPiPackage != piPackage;
          assert builtins.elem finalPiPackage homeWithProfiles.config.home.packages;
          assert builtins.elem herdrPackage homeWithProfiles.config.home.packages;
          assert piPackage == inputs.llm-agents.packages.${system}.pi;
          assert herdrPackage == inputs.llm-agents.packages.${system}.herdr;
          assert extensionPackages.superpowers-bootstrap == realizedSkills.repositories.superpowers;
          assert builtins.length duplicatePiPackage.settingsPackages == 1;
          assert !conflictingPiPackage.success;
          pkgs.runCommand "declarative-pi-packages-check"
            {
              extensionRoots = builtins.attrValues extensionPackages;
              profileActivation = homeWithProfiles.activationPackage;
              nativeBuildInputs = [
                pkgs.coreutils
                pkgs.jq
              ];
            }
            ''
              set -euo pipefail

              check_package() {
                root="$1"
                extension="$2"
                expected_peers="$3"
                test -d "$root"
                test -f "$root/package.json"
                ${pkgs.jq}/bin/jq -e \
                  --arg extension "$extension" \
                  '.pi.extensions == [$extension]
                   and (.pi.skills // []) == []
                   and (.pi.prompts // []) == []
                   and (.pi.themes // []) == []' \
                  "$root/package.json" >/dev/null
                ${pkgs.nodejs_24}/bin/node ${piDependencyContractProbe} "$root" "$expected_peers"
                (cd "$root" && ${pkgs.nodejs_24}/bin/npm ls --omit=dev --all >/dev/null)
              }

              ask_user_peers=${
                lib.escapeShellArg (
                  builtins.toJSON {
                    "@earendil-works/pi-coding-agent" = "*";
                    "@earendil-works/pi-tui" = "*";
                    typebox = "*";
                  }
                )
              }
              mcp_adapter_peers=${
                lib.escapeShellArg (
                  builtins.toJSON {
                    "@earendil-works/pi-ai" = "*";
                    "@earendil-works/pi-coding-agent" = "*";
                    "@earendil-works/pi-tui" = "*";
                    typebox = "*";
                  }
                )
              }
              playwright_peers=$(
                ${pkgs.jq}/bin/jq -c '.peerDependencies' ${inputs.pi-playwright}/package.json
              )
              web_access_peers="$mcp_adapter_peers"

              check_package ${extensionPackages.jevons} ./pi/extension.ts "$mcp_adapter_peers"
              test ! -e ${extensionPackages.jevons}/.env
              test ! -e ${extensionPackages.jevons}/.jevons
              (cd ${extensionPackages.jevons} && ${pkgs.nodejs_24}/bin/node --input-type=module <<'EOF'
              const sdk = await import("@typesafe-ai/sdk");
              const diff = await import("diff");
              if (typeof sdk.TypeSafeClient !== "function" || typeof diff.parsePatch !== "function") {
                throw new Error("Jevons runtime dependencies are unavailable");
              }
              EOF
              )

              check_package ${extensionPackages.ask-user} ./index.ts "$ask_user_peers"
              check_package ${extensionPackages.pi-mcp-adapter} ./index.ts "$mcp_adapter_peers"
              check_package ${extensionPackages.pi-playwright} ./dist/index.js "$playwright_peers"
              check_package ${extensionPackages.web-access} ./index.ts "$web_access_peers"

              test -d ${extensionPackages.pi-playwright}/node_modules/playwright
              test -d ${extensionPackages.pi-playwright}/node_modules/playwright-core
              ${pkgs.gnugrep}/bin/grep -Fq \
                ${lib.escapeShellArg (toString pkgs.playwright-driver.browsers)} \
                ${extensionPackages.pi-playwright}/dist/index.js
              ! ${pkgs.gnugrep}/bin/grep -Fq 'params?.executablePath' \
                ${extensionPackages.pi-playwright}/dist/index.js
              ${pkgs.gnugrep}/bin/grep -Fq 'Only HTTP(S) URLs are allowed' \
                ${extensionPackages.pi-playwright}/dist/index.js
              ${pkgs.gnugrep}/bin/grep -Fq 'basename(params.filename' \
                ${extensionPackages.pi-playwright}/dist/index.js
              ${pkgs.gnugrep}/bin/grep -Fq 'JSON.stringify(value, null, 2) ?? String(value)' \
                ${extensionPackages.pi-playwright}/dist/index.js
              ${pkgs.gnugrep}/bin/grep -Fq 'browser_evaluate requires a JavaScript function' \
                ${extensionPackages.pi-playwright}/dist/index.js
              ! ${pkgs.gnugrep}/bin/grep -Fq 'evaluate(params.function)' \
                ${extensionPackages.pi-playwright}/dist/index.js
              test ! -e ${inputs.pi-ask-user}/package-lock.json
              test ! -e ${extensionPackages.ask-user}/package-lock.json
              test ! -e ${extensionPackages.ask-user}/node_modules
              ${pkgs.jq}/bin/jq -e \
                '.pi.extensions == ["./.pi/extensions/superpowers.ts"]
                 and (.pi.skills // []) == []
                 and (.pi.prompts // []) == []
                 and (.pi.themes // []) == []' \
                ${extensionPackages.superpowers-bootstrap}/package.json >/dev/null

              test -d ${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/client
              test -d ${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/ext-apps
              test -d ${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/sdk
              test -d ${extensionPackages.web-access}/node_modules/@mozilla/readability
              ${pkgs.jq}/bin/jq -e \
                '.packages[""].dependencies["@modelcontextprotocol/ext-apps"] == "^1.2.2"
                 and .packages["node_modules/@modelcontextprotocol/ext-apps"].version != null
                 and .packages["node_modules/@modelcontextprotocol/sdk"].version != null' \
                ${extensionPackages.pi-mcp-adapter}/package-lock.json >/dev/null
              test ! -e ${extensionPackages.web-access}/node_modules/typebox

              # Import mandatory installed dependencies only. Pi host peers are
              # checked as manifest/closure invariants and are never imported alone.
              (cd ${extensionPackages.pi-mcp-adapter} && ${pkgs.nodejs_24}/bin/node --input-type=module <<'EOF'
              await import("@modelcontextprotocol/client");
              await import("@modelcontextprotocol/core");
              await import("@modelcontextprotocol/ext-apps");
              await import("ajv");
              EOF
              )
              (cd ${extensionPackages.web-access} && ${pkgs.nodejs_24}/bin/node --input-type=module <<'EOF'
              await import("@mozilla/readability");
              await import("linkedom");
              await import("unpdf");
              EOF
              )
              test -f ${extensionPackages.superpowers-bootstrap}/skills/using-superpowers/SKILL.md
              test ! -e ${extensionPackages.superpowers-bootstrap}/skills/writing-skills/render-graphs.js

              bootstrap=${extensionPackages.superpowers-bootstrap}/.pi/extensions/superpowers.ts
              ! ${pkgs.gnugrep}/bin/grep -Fq 'resources_discover' "$bootstrap"
              ${pkgs.gnugrep}/bin/grep -Fq 'superpowers:using-superpowers bootstrap for pi' "$bootstrap"
              ${pkgs.gnugrep}/bin/grep -Fq '## Pi tool mapping' "$bootstrap"
              ${pkgs.gnugrep}/bin/grep -Fq 'Pi has native skills' "$bootstrap"
              test -f ${herdrAgentStateResource.realization.source}
              test -x ${piPackage}/bin/pi
              test -x ${herdrPackage}/bin/herdr
              test "$(readlink "$profileActivation/home-path/bin/pi")" = ${lib.escapeShellArg "${finalPiPackage}/bin/pi"}
              test "$(readlink "$profileActivation/home-path/bin/herdr")" = ${lib.escapeShellArg "${herdrPackage}/bin/herdr"}

              agent="$TMPDIR/agent"
              work="$TMPDIR/work"
              marker="$TMPDIR/resources-loaded"
              npm_marker="$TMPDIR/npm-invoked"
              mkdir -p "$agent/extensions" "$work" "$TMPDIR/home" "$TMPDIR/runtime"
              ln -s ${herdrAgentStateResource.realization.source} \
                "$agent/extensions/herdr-agent-state.ts"

              fake_npm="$TMPDIR/npm-must-not-run"
              cat > "$fake_npm" <<EOF
              #!${pkgs.runtimeShell}
              touch "$npm_marker"
              exit 99
              EOF
              chmod +x "$fake_npm"

              ${pkgs.jq}/bin/jq -n \
                --arg npm "$fake_npm" \
                --argjson packages ${lib.escapeShellArg (builtins.toJSON allExtensionPackages)} \
                '{
                  packages: $packages,
                  npmCommand: [$npm],
                  enableInstallTelemetry: false,
                  defaultProjectTrust: "never"
                }' > "$agent/settings.json"

              cd "$work"
              set +e
              printf '%s\n' '{"type":"prompt","message":"/dendritic-offline-smoke"}' | \
                env -i \
                  HOME="$TMPDIR/home" \
                  TMPDIR="$TMPDIR/runtime" \
                  PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.coreutils ])} \
                  PI_CODING_AGENT_DIR="$agent" \
                  PI_OFFLINE=1 \
                  NPM_CONFIG_OFFLINE=true \
                  DENDRITIC_SLOP_SMOKE_MARKER="$marker" \
                  ${pkgs.coreutils}/bin/timeout 60 \
                  ${lib.getExe piPackage} --offline --mode rpc --no-session --no-context-files \
                    -e ${piResourceProbe} > "$TMPDIR/pi.stdout" 2> "$TMPDIR/pi.stderr"
              status=$?
              set -e

              if [ "$status" -ne 0 ]; then
                cat "$TMPDIR/pi.stdout" >&2
                cat "$TMPDIR/pi.stderr" >&2
                exit "$status"
              fi
              test -f "$marker"
              ${pkgs.gnugrep}/bin/grep -Fq '"command":"prompt","success":true' "$TMPDIR/pi.stdout"
              ! ${pkgs.gnugrep}/bin/grep -Eq 'extension_error|Failed to load extension' \
                "$TMPDIR/pi.stdout" "$TMPDIR/pi.stderr"
              test ! -e "$npm_marker"
              test ! -e "$agent/npm"
              test ! -e "$agent/git"

              touch "$out"
            '';
        mcp-registry =
          assert catalog.mcps.browser.transport.type == "local";
          assert catalog.mcps.context7.transport.type == "remote";
          assert catalog.mcps.browser.serverId == "agent-browser";
          assert catalog.mcps.context7.serverId == "context7";
          assert catalog.mcps.context7.secretFiles.apiKeyFile.environment == "CONTEXT7_API_KEY";
          assert home.options.dendriticSlop.mcps.context7.secrets ? apiKeyFile;
          assert !home.config.dendriticSlop.mcps.context7.enable;
          assert home.config.dendriticSlop.mcps.context7.secrets.apiKeyFile == null;
          assert !(home.config.xdg.configFile ? "mcp/mcp.json");
          assert !(home.options.dendriticSlop ? context7);
          assert !(home.options.dendriticSlop.targets ? context7);
          assert !homeWithRelativeSecret.success;
          assert !homeWithLiteralSecret.success;
          assert !homeWithNixPathSecret.success;
          assert !homeWithStoreSecret.success;
          assert !homeWithUnsafeSecretExtension.success;
          assert !homeWithMcpCollision.success;
          assert !duplicateMcpId;
          assert homeWithMergedMcps.config.dendriticSlop.mcps.browser.enable;
          assert homeWithMergedMcps.config.dendriticSlop.mcps.context7.enable;
          assert homeWithMergedMcps.config.dendriticSlop.extensions.pi-mcp-adapter.enable;
          assert mergedMcpJson == expectedMergedMcpJson;
          assert
            homeWithContext7.config.programs.pi.coding-agent.environment.CONTEXT7_API_KEY.file
            == context7SecretPath;
          assert !(homeWithContext7NoSecret.config.programs.pi.coding-agent.environment ? CONTEXT7_API_KEY);
          assert !lib.hasInfix context7SecretPath homeWithContext7.config.xdg.configFile."mcp/mcp.json".text;
          assert lib.hasInfix "Bearer \${CONTEXT7_API_KEY}"
            homeWithContext7.config.xdg.configFile."mcp/mcp.json".text;
          assert bridgeTrue.mcps.context7.enable;
          assert bridgeTrue.mcps.context7.secrets.apiKeyFile == context7SecretPath;
          assert !bridgeFalse.mcps.context7.enable;
          assert catalog.extensions.ask-user.secretCapable;
          assert catalog.extensions.herdr-agent-state.secretCapable;
          assert catalog.extensions.jevons.secretCapable;
          assert catalog.extensions.pi-mcp-adapter.secretCapable;
          assert catalog.extensions.pi-playwright.secretCapable;
          assert catalog.extensions.web-access.secretCapable;
          assert !catalog.extensions.superpowers-bootstrap.secretCapable;
          pkgs.runCommand "mcp-registry-check"
            {
              mcpConfig = pkgs.writeText "expected-mcp.json" (
                homeWithMergedMcps.config.xdg.configFile."mcp/mcp.json".text
              );
              nativeBuildInputs = [
                pkgs.coreutils
                pkgs.jq
              ];
            }
            ''
              set -euo pipefail

              test "$(jq -r '.mcpServers | keys | join(" ")' "$mcpConfig")" = \
                'agent-browser context7 linear'
              test "$(jq -r '.mcpServers["agent-browser"].command' "$mcpConfig")" = \
                ${lib.escapeShellArg agentBrowserCommand}
              test "$(jq -r '.mcpServers["agent-browser"].args | join(" ")' "$mcpConfig")" = mcp
              test "$(jq -r '.mcpServers.context7.headers.Authorization' "$mcpConfig")" = \
                'Bearer ''${CONTEXT7_API_KEY}'
              ! grep -F ${lib.escapeShellArg context7SecretPath} "$mcpConfig"
              ${agentBrowserCommand} mcp --help > "$TMPDIR/agent-browser-mcp-help"
              ${pkgs.gnugrep}/bin/grep -Fq 'Start an MCP stdio server' \
                "$TMPDIR/agent-browser-mcp-help"

              agent="$TMPDIR/agent"
              work="$TMPDIR/work"
              home_dir="$TMPDIR/home"
              runtime="$TMPDIR/runtime"
              marker="$TMPDIR/adapter-secret-invoked"
              mkdir -p "$agent" "$work" "$home_dir" "$runtime"
              runtime_secret="runtime-$RANDOM-$$"

              cd "$work"
              set +e
              {
                printf '%s\n' '{"type":"prompt","message":"/dendritic-mcp-secret-smoke"}'
                for attempt in $(seq 1 600); do
                  [ ! -f "$marker" ] || break
                  sleep 0.1
                done
              } | \
                env -i \
                  HOME="$home_dir" \
                  TMPDIR="$runtime" \
                  PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.coreutils ])} \
                  PI_CODING_AGENT_DIR="$agent" \
                  PI_OFFLINE=1 \
                  CONTEXT7_API_KEY="$runtime_secret" \
                  DENDRITIC_SLOP_MCP_SECRET_MARKER="$marker" \
                  ${pkgs.coreutils}/bin/timeout 90 \
                  ${lib.getExe piPackage} --offline --mode rpc --no-session --no-context-files \
                    -e ${mcpSecretProbe} > "$TMPDIR/pi-mcp.stdout" 2> "$TMPDIR/pi-mcp.stderr"
              status=$?
              set -e

              if [ "$status" -ne 0 ]; then
                cat "$TMPDIR/pi-mcp.stdout" >&2
                cat "$TMPDIR/pi-mcp.stderr" >&2
                exit "$status"
              fi
              if [ ! -f "$marker" ]; then
                cat "$TMPDIR/pi-mcp.stdout" >&2
                cat "$TMPDIR/pi-mcp.stderr" >&2
                echo "MCP secret adapter smoke test did not write its marker" >&2
                exit 1
              fi
              test "$(cat "$marker")" = invoked
              ! grep -F "$runtime_secret" "$mcpConfig" "$marker"
              ! grep -Eq 'extension_error|Failed to load extension' \
                "$TMPDIR/pi-mcp.stdout" "$TMPDIR/pi-mcp.stderr"

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
          assert catalog.extensions.superpowers-bootstrap.repository == "superpowers";
          pkgs.runCommand "registry-schema-check" { } ''
            touch "$out"
          '';
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
        all-skills = allSkills;
        linear-mcp =
          assert !home.config.dendriticSlop.mcps.linear.enable;
          assert !(home.options.dendriticSlop.targets ? linear);
          assert catalog.mcps.linear.transport.auth == "oauth";
          assert catalog.mcps.linear.secretFiles == { };
          assert homeWithOnlyLinear.config.programs.pi.coding-agent.enable;
          assert linearMcpJson == { mcpServers.linear = expectedMergedMcpJson.mcpServers.linear; };
          pkgs.runCommand "linear-mcp-config-check" { nativeBuildInputs = [ pkgs.jq ]; } ''
            jq -e '
              .mcpServers.linear.url == "https://mcp.linear.app/mcp" and
              .mcpServers.linear.auth == "oauth" and
              .mcpServers.linear.lifecycle == "lazy" and
              .mcpServers.context7.url == "https://mcp.context7.com/mcp"
            ' ${homeWithMergedMcps.config.xdg.configFile."mcp/mcp.json".source}
            jq -e '.mcpServers | keys == ["linear"]' \
              ${homeWithOnlyLinear.config.xdg.configFile."mcp/mcp.json".source}
            touch "$out"
          '';
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
      };

      formatter = pkgs.nixfmt-tree;
    };
}
