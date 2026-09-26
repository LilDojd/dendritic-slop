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
- `skills.<name>`: pinned skill directories. `skillSets.{core,rust,python}` group them.
- `packages.<system>.*`: Pi extensions (`pi-ask-user`, `pi-mcp-adapter`, `pi-web-access`, `pi-playwright`, `pi-goal`, `pi-starship`, `pi-jev-compact`, `jevons`), `tsk`, and Herdr plugin roots (`herdr-plugin-jj-workspace`, `herdr-plugin-tsk`).

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
package to `llm-agents.nix`. `dendriticSlop.piPackages` collects Pi packages from any module
into `settings.packages`, which pi.nix does not merge. `pi-mcp-adapter` is added whenever
`programs.mcp.servers` is non-empty, so Pi reads the same servers.

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
