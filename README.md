# dendritic-slop

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
      superpowers.enable = false;
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

Home Manager owns `~/.agents/skills` when dendritic-slop is enabled. If that path or `~/.agents/.skill-lock.json` already exists, set `dendriticSlop.migrations.globalSkills.takeOver = true` for the ownership transaction. Existing content is retained under `~/.local/state/dendritic-slop/global-skills/backups`; unmanaged replacements are never overwritten.

## TypeSafe

The official skill and independent Pi extension are opt-in, outside the default profiles:

```nix
dendriticSlop = {
  skills.typesafe-ai.enable = true;
  extensions.pi-typesafe.enable = true;
};
```

After rebuilding, restart Pi and use `/skill:typesafe-ai` for TypeSafe development guidance.
Run `/typesafe login` to verify and save your API key outside the Nix store, then
`/typesafe test` for a sample request. `/typesafe enable` permits agent calls for
that session only; submitted state and questions go to `api.typesafe.ai` and may
incur charges. No automatic opt-in is configured. The extension also accepts
`TYPESAFE_API_KEY` from the runtime environment; never put its value in Nix configuration.

To use agenix-rekey on NixOS or nix-darwin, declare the encrypted secret in your
host flake and pass its decrypted path, just like an MCP key:

```nix
{ config, ... }:
{
  age.secrets.typesafeApiKey = {
    rekeyFile = ./typesafeApiKey.age;
    owner = config.dendriticSlop.username;
    mode = "0400";
  };

  dendriticSlop.extensions.pi-typesafe = {
    enable = true;
    secrets.apiKeyFile = config.age.secrets.typesafeApiKey.path;
  };
}
```

With plain agenix, use `file` instead of `rekeyFile`. The consuming flake must
already configure agenix and its identities. Home Manager exposes the same
`secrets.apiKeyFile` option for an existing user-readable decrypted file.

Pi reads the file into `TYPESAFE_API_KEY` at launch; the plaintext never enters
the Nix store or generated settings. Restart Pi after rotating the key. No
`/typesafe login` is needed, but `/typesafe enable` is still required each session.
The key is available to Pi extensions and child processes, so selected extensions
must be reviewed as secret-capable. Leaving the option unset preserves manual login.

## Security model

Resources are selected from a closed typed catalog. External sources are pinned, projected through reviewed allowlists, and built with Nix. Activation does not fetch packages. Credentials remain outside the Nix store; MCP and TypeSafe secret options accept only absolute runtime file paths.

Networked and executable leaves expose capability metadata in the generated catalog. Herdr plugins are disabled by default and execute with the user's authority. Plugin activation changes only registrations and keybinding blocks still marked as owned by dendritic-slop.

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
