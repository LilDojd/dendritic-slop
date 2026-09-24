# dendritic-slop

![100% slop](https://img.shields.io/badge/%F0%9F%A4%96%20100%25-slop-a3e635?style=plastic&labelColor=4c1d95 "100% LLM-generated")

Declarative, reviewed Pi, Claude Code, and LLM tooling for NixOS, nix-darwin, and Home Manager.

## Flake input

```nix
inputs.dendritic-slop = {
  url = "github:LilDojd/dendritic-slop";
  inputs = {
    home-manager.follows = "home-manager";
    impermanence.follows = "impermanence";
    nix-darwin.follows = "nix-darwin";
    nixpkgs.follows = "nixpkgs";
    systems.follows = "systems";
  };
};
```

The flake configures the Numtide binary cache used by packages from `llm-agents.nix`. A consuming flake must allow that cache configuration.

## NixOS

Import Home Manager, impermanence, and the aggregate module:

```nix
{
  imports = [ inputs.dendritic-slop.modules.nixos.slop ];

  dendriticSlop = {
    enable = true;
    username = "alice";

    targets.claude.enable = true;

    profiles = {
      core.enable = true;
      rust.enable = true;
      python.enable = true;
      web.enable = true;
    };

    skills.ty.enable = false;
    herdr.plugins.jj-workspace.enable = true;
    mcps.context7 = {
      enable = true;
      secrets.apiKeyFile = "/run/agenix/context7-api-key";
    };
  };
}
```

The NixOS aggregate persists `.pi/agent` and `.local/state/dendritic-slop`, plus `.claude` when the Claude target is enabled. Set `dendriticSlop.targets.persistence.enable = false` to disable this persistence policy.

## nix-darwin

Import Home Manager and `inputs.dendritic-slop.modules.darwin.slop`. The selection options are the same as the NixOS example.

## Home Manager

```nix
{
  imports = [ inputs.dendritic-slop.modules.homeManager.slop ];

  dendriticSlop = {
    enable = true;
    profiles.core.enable = true;
    profiles.rust.enable = true;
  };
}
```

Profiles apply defaults. Explicit `targets.<name>.enable`, `skills.<name>.enable`, `mcps.<name>.enable`, `extensions.<name>.enable`, `tools.<name>.enable`, and `herdr.plugins.<name>.enable` values take precedence.

Home Manager owns `~/.agents/skills` when enabled and refuses to overwrite unmanaged content. Move conflicting files aside manually before activation.

## Claude Code

`dendriticSlop.targets.claude.enable` installs Claude Code from `llm-agents.nix`
through Home Manager's `programs.claude-code`. Every harness receives the same
selection: each selected skill is linked whole into `~/.claude/skills/<name>`
(Pi reads `~/.agents/skills`), and each selected MCP server is rendered into the
generated `hm` personal plugin. Secret-backed MCP headers are produced at
connection time by a `headersHelper` that reads the runtime secret file.

With the Herdr target enabled, Claude also receives Herdr's session hook and its
versioned hook file, so `herdr integration status` reports it installed. With the
rules target enabled, every harness receives the global agent context from
`resources/rules/context.md` plus its declarative self-management rules (Pi's
rules and Claude's `~/.claude/CLAUDE.md`).

`settings.json` is a read-only store link: set preferences through
`programs.claude-code.settings` in the consuming configuration. The auto-updater
is disabled; updates arrive through the flake. Do not use `claude plugin install`
or `claude mcp add` for global tooling.

## tsk (explicit opt-in)

Enable `dendriticSlop.tools.tsk.enable` for the CLI/TUI and
`dendriticSlop.skills.tsk-cli.enable` for the agent skill. With Herdr enabled,
`dendriticSlop.herdr.plugins.tsk.enable` adds the board on `prefix+t` and a
quick-capture action. Quick capture has no default shortcut, preserving the
Jujutsu plugin's `prefix+a` binding.

The NixOS persistence policy also retains `~/.tsk` when any tsk resource is
selected. Update through the flake, not `tsk update`; skill and plugin setup are
managed declaratively, so do not run `tsk setup`.

## Herdr Projects (explicit opt-in)

Enable `dendriticSlop.herdr.plugins.projects.enable` with the Herdr target to
install the `herdr-projects` CLI and register its actions, popups, and background
ticker. Create a project from your shell with
`herdr-projects new "Refactor" --repo "$PWD"` (not `herdr projects`). Open its overview
with `herdr plugin action invoke open-popup --plugin herdr-projects`. No shortcut
is assigned, preserving the Jujutsu plugin's `prefix+a` binding.

Optional sidebar rows and agent progress hooks are not configured. Do not run
upstream's `configure` against managed settings or use `update`; setup and updates
belong in the flakes. NixOS persistence retains `~/.herdr-projects` and
`~/.config/herdr-projects`. Projects uses Git worktrees, not Jujutsu workspaces.

## Security model

Resources are selected from a closed typed catalog. External sources are pinned, projected through reviewed allowlists, and built with Nix. Source updates must be reviewed in their commit or pull request; `flake.lock` records the installed revisions, not proof of review. Activation does not fetch packages. Credentials remain outside the Nix store; MCP secret options accept only absolute runtime file paths.

Networked and executable leaves expose capability metadata in the generated catalog. Herdr plugins are disabled by default and execute with the user's authority. Plugin activation changes only registrations and keybinding blocks still marked as owned by dendritic-slop.

## Jevons (explicit opt-in)

Set `dendriticSlop.extensions.jevons.enable = true;` in the consuming host or Home Manager configuration. No profile enables it by default. The pinned package supplies its two runtime dependencies; Pi and TypeBox remain host peers. Activation performs no package installation.

Installing Jevons opts into sending bounded task text, skill metadata, diagnostics and selected source to TypeSafe in trusted projects; no `--jevons` flag is required. Recovery defaults to shadow mode, tool feedback is disabled, and usage reporting does not enforce spending limits. Use `/jevons pause` to stop requests. Verification uses the host's Git/Jujutsu executables.

Supply `TYPESAFE_API_KEY` through the Pi process environment or the consuming Home Manager configuration's `programs.pi.coding-agent.environment.TYPESAFE_API_KEY.file`, pointing to an absolute runtime secret path. Never put the key, an `.env` file or transient session state in this flake or the Nix store.

## Inspection outputs

Per-system packages include:

- `skill-<name>` for each skill leaf;
- `extension-<name>` for package-backed Pi extensions;
- `tool-<name>` for command-line tools;
- `herdr-plugin-<name>` for Herdr plugin roots;
- `all-<profile>` for each canonical profile;
- `resource-catalog`, `option-reference`, and `docs`.

Each `all-<profile>` package contains the profile manifest, links to its declared leaves, and a collision-checked `bin` directory for declared executables.

## Development

```console
nix fmt
nix flake check --accept-flake-config --no-eval-cache --no-build --all-systems
```

The generated [selection options](https://lildojd.github.io/dendritic-slop/options.html) and [resource catalog](https://lildojd.github.io/dendritic-slop/catalog.html) are the current public reference.
