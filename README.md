# dendritic-slop

![100% slop](https://img.shields.io/badge/%F0%9F%A4%96%20100%25-slop-a3e635?style=plastic&labelColor=4c1d95 "100% LLM-generated")

Pinned agent skills, Pi extensions, Herdr plugins, and thin Home Manager modules for Claude Code, Pi, and Herdr.

The modules only fill gaps in upstream options. Configure agents through
`programs.claude-code`, `programs.pi.coding-agent`, and `programs.mcp` directly.

## Flake input

```nix
inputs.dendritic-slop = {
  url = "github:LilDojd/dendritic-slop";
  inputs = {
    home-manager.follows = "home-manager";
    nixpkgs.follows = "nixpkgs";
  };
};
```

The flake configures the Numtide binary cache used by packages from `llm-agents.nix`.

## Outputs

- `modules.homeManager.default` imports every module below.
- `skills.<name>`: pinned skill directories. `skillSets.{core,rust,python,pydantic}` group them.
  `pydantic` covers Pydantic, Pydantic AI, and Logfire; the Pydantic AI migration skills are
  only in `skills`. Logfire skills expect the hosted Logfire MCP server in `programs.mcp.servers`.
- `packages.<system>.*`: Grafana MCP (`mcp-grafana`), Pi (with the standalone codemode worker embedded), Pi extensions (`pi-ask-user`, `pi-claude-bridge`, `pi-web-access`, `pi-playwright`, `pi-goal`, `pi-starship`, `pi-jev-compact`, `pi-jev`), `tsk`, and Herdr plugin roots (`herdr-plugin-jj-workspace`, `herdr-plugin-tsk`).

## Home Manager

```nix
{ inputs, pkgs, ... }:
let
  slop = inputs.dendritic-slop;
  slopPackages = slop.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ slop.modules.homeManager.default ];

  dendriticSlop.skills = slop.skillSets.core // slop.skillSets.rust // {
    inherit (slop.skills) uncomplect;
  };

  programs.claude-code.enable = true;
  programs.pi.coding-agent.enable = true;
  dendriticSlop.piPackages = [ slopPackages.pi-ask-user ];

  programs.mcp = {
    enable = true;
    servers.linear.url = "https://mcp.linear.app/mcp";
  };

  dendriticSlop.herdr = {
    enable = true;
    plugins = [ slopPackages.herdr-plugin-jj-workspace ];
  };
}
```

When used from NixOS, pass the module through `home-manager.sharedModules`.

### `claude`

Defaults `programs.claude-code.package` to `llm-agents.nix`, disables the auto-updater,
and enables `enableMcpIntegration`, so `programs.mcp.servers` reach Claude Code.

### `pi`

Imports the [pi.nix](https://github.com/lukasl-dev/pi.nix) module and defaults its
package to this flake's `pi`, based on `llm-agents.nix` with the codemode worker embedded.
`dendriticSlop.piPackages` collects Pi packages from any module
into `settings.packages`, which pi.nix does not merge. `programs.mcp.servers` are written to
Pi's native `~/.pi/agent/mcp.json`. The file is read-only, so change exposure and enablement
in Nix instead of through `/mcp` or `pi mcp add`.

`pi-claude-bridge` registers Claude Code as a Pi provider. Add it to
`dendriticSlop.piPackages` and declare `~/.pi/agent/claude-bridge.json` through
Home Manager with `provider.pathToClaudeCodeExecutable = lib.getExe config.programs.claude-code.package`.
Set `provider.plan` (`"pro"` or `"max"`) and `askClaude.enabled` explicitly so the
startup notice does not try to rewrite the managed config. AskClaude is opt-in;
Extra Usage is disabled by default. Claude authentication and sessions stay outside the store.

`pi-jev` replaces Jevons with `jev_ask` and automatic shadow-mode tool/output
judges. It uses the runtime `TYPESAFE_API_KEY`; truncated arguments and output
are sent to TypeSafe, including possible secrets. The packaged client only
allows `https://api.typesafe.ai/v1/systemone`, so project config cannot redirect
the key to another endpoint. Configure judges through `~/.pi/agent/pi-jev.json`.

### `skills`

`dendriticSlop.skills` links each skill into `programs.claude-code.skills` and
`~/.agents/skills`, which Pi and other harnesses read.

### `rules`

Appends `resources/rules/context.md` to Claude Code's `CLAUDE.md` and Pi's system prompt.

### `mcp`

`dendriticSlop.mcpHeaderSecrets.<server>.<VARIABLE> = "/run/agenix/…"` substitutes
runtime secret files into `${VARIABLE}` in `programs.mcp.servers.<server>.headers`.
Claude Code resolves them with a `headersHelper`, and Pi receives them as environment
variables, so secrets never enter the store.

### Grafana MCP

The `mcp-grafana` package reuses the version pinned by Nixpkgs. Enable it in the
consuming Home Manager configuration:

```nix
programs.mcp.servers.grafana = {
  command = lib.getExe slopPackages.mcp-grafana;
  args = [ "--disable-write" ];
};
```

Set `GRAFANA_URL` and `GRAFANA_SERVICE_ACCOUNT_TOKEN` in the agent's environment
before launching Claude Code or Pi. The stdio server inherits them; credentials
stay outside the Nix store. Remove `--disable-write` to allow mutations.

### `herdr`

`dendriticSlop.herdr.enable` installs Herdr, its skill, the Pi and Claude Code agent-state
integrations, a validated `config.toml` from `dendriticSlop.herdr.settings`, and a
`plugins.json` registering `dendriticSlop.herdr.plugins`. Both files are read-only, so
change them in Nix instead of through `herdr plugin` or the settings UI.

## Development

```console
nix fmt
nix flake check --accept-flake-config
```

`checks.<system>.home` builds a Home Manager generation that uses every module.
