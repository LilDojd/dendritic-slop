# dendritic-slop

![100% slop](https://img.shields.io/badge/%F0%9F%A4%96%20100%25-slop-a3e635?style=plastic&labelColor=4c1d95 "100% LLM-generated")

Declarative, reviewed Pi and LLM tooling for NixOS, nix-darwin, and Home Manager.

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

The NixOS aggregate persists `.pi/agent` and `.local/state/dendritic-slop`. Set `dendriticSlop.targets.persistence.enable = false` to disable this persistence policy.

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

## tsk (explicit opt-in)

Enable `dendriticSlop.tools.tsk.enable` for the CLI/TUI and
`dendriticSlop.skills.tsk-cli.enable` for the agent skill. With Herdr enabled,
`dendriticSlop.herdr.plugins.tsk.enable` adds the board on `prefix+t` and a
quick-capture action. Quick capture has no default shortcut, preserving the
Jujutsu plugin's `prefix+a` binding.

The NixOS persistence policy also retains `~/.tsk` when any tsk resource is
selected. Update through the flake, not `tsk update`; skill and plugin setup are
managed declaratively, so do not run `tsk setup`.

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
