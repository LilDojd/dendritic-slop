{ inputs, superpowersPackage }:
let
  packageVersion = source: (builtins.fromJSON (builtins.readFile (source + "/package.json"))).version;
in
{
  ask-user = {
    title = "Ask user";
    description = "Collect structured choices and freeform answers from the user.";
    homepage = "https://github.com/edlsh/pi-ask-user";
    profiles = [ "core" ];
    environment.PI_ASK_USER_DISPLAY_MODE.value = "inline";
    capabilities.executesCode = true;
    secretCapable = true;
    realization = {
      type = "package";
      package = pkgs: pkgs.callPackage ../packages/pi-ask-user.nix { source = inputs.pi-ask-user; };
      packageId = "pi-ask-user";
      version = packageVersion inputs.pi-ask-user;
    };
  };

  herdr-agent-state = {
    title = "Herdr Pi integration";
    description = "Report Pi session identity and working, blocked, and idle states to Herdr.";
    homepage = "https://github.com/herdrdev/herdr";
    profiles = [ "core" ];
    requiresTargets = [ "herdr" ];
    capabilities.executesCode = true;
    secretCapable = true;
    realization = {
      type = "path";
      source = inputs.herdr-src + "/src/integration/assets/pi/herdr-agent-state.ts";
      destination = ".pi/agent/extensions/herdr-agent-state.ts";
    };
  };

  pi-mcp-adapter = {
    title = "Pi MCP adapter";
    description = "Connect Pi to local and remote Model Context Protocol servers.";
    homepage = "https://github.com/nicobailon/pi-mcp-adapter";
    profiles = [ "core" ];
    requiresTargets = [ "pi" ];
    capabilities = {
      executesCode = true;
      network = true;
      mutatesUserConfig = true;
    };
    secretCapable = true;
    realization = {
      type = "package";
      package = pkgs: pkgs.callPackage ../packages/pi-mcp-adapter.nix { source = inputs.pi-mcp-adapter; };
      packageId = "pi-mcp-adapter";
      version = packageVersion inputs.pi-mcp-adapter;
    };
  };

  superpowers-bootstrap = {
    title = "Superpowers Pi bootstrap";
    description = "Inject the reviewed Superpowers bootstrap and Pi tool mapping without duplicate skill discovery.";
    homepage = "https://github.com/obra/superpowers";
    repository = "superpowers";
    profiles = [ "superpowers" ];
    requiresTargets = [ "pi" ];
    capabilities.executesCode = true;
    realization = {
      type = "package";
      package = superpowersPackage;
      packageId = "superpowers";
      version = packageVersion inputs.superpowers;
    };
  };

  web-access = {
    title = "Web access";
    description = "Add web search, URL fetching, source checking, and local document extraction.";
    homepage = "https://github.com/nicobailon/pi-web-access";
    profiles = [ "web" ];
    capabilities = {
      executesCode = true;
      network = true;
      readsSecrets = true;
    };
    secretCapable = true;
    realization = {
      type = "package";
      package = pkgs: pkgs.callPackage ../packages/pi-web-access.nix { source = inputs.pi-web-access; };
      packageId = "pi-web-access";
      version = packageVersion inputs.pi-web-access;
    };
  };
}
