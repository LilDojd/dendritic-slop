{ inputs }:
{
  browser = {
    title = "Agent browser";
    description = "Expose the pinned agent-browser automation server over local MCP stdio.";
    homepage = "https://github.com/vercel-labs/agent-browser";
    profiles = [ "web" ];
    requiresTargets = [ "pi" ];
    requiresResources = [ "extensions.pi-mcp-adapter" ];
    capabilities = {
      executesCode = true;
      network = true;
    };
    transport = {
      type = "local";
      package = pkgs: inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
      executable = "agent-browser";
      arguments = [ "mcp" ];
    };
    lifecycle = "lazy";
    serverId = "agent-browser";
  };

  context7 = {
    title = "Context7";
    description = "Look up current library documentation and examples.";
    homepage = "https://context7.com";
    profiles = [ ];
    requiresTargets = [ "pi" ];
    requiresResources = [ "extensions.pi-mcp-adapter" ];
    capabilities = {
      network = true;
      readsSecrets = true;
    };
    transport = {
      type = "remote";
      url = "https://mcp.context7.com/mcp";
    };
    lifecycle = "lazy";
    secretFiles.apiKeyFile = {
      description = "Absolute runtime path to a file containing the Context7 API key.";
      environment = "CONTEXT7_API_KEY";
      headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
    };
  };
}
