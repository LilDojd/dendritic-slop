# dendritic-slop

Minimal, declarative Pi and LLM tooling for NixOS and nix-darwin.

The repository follows the [Dendritic pattern](https://dendrix.denful.dev/Dendritic.html): every file in `modules/` is a flake-parts module, and features are exported as `modules.<class>.<aspect>`.

## Resources

Home Manager modules:

- `pi` — Pi plus the pinned MCP adapter
- `context7` — Context7 MCP configuration with an optional runtime key file
- `herdr` — Herdr, its Pi skill, and its agent-state extension
- `skills` — the `bro` and Jujutsu skills
- `git` — ignores local MCP configuration
- `rules` — concise declarative-management policy
- `slop` — all of the above

System modules:

- `nixos.slop` — attaches `homeManager.slop` and persists Pi state
- `darwin.slop` — attaches `homeManager.slop`
- `nixos.persistence` — Pi persistence only

## Consumer

```nix
inputs.dendritic-slop = {
  url = "github:LilDojd/dendritic-slop";
  inputs = {
    flake-parts.follows = "flake-parts";
    herdr.follows = "herdr";
    home-manager.follows = "home-manager";
    impermanence.follows = "impermanence";
    import-tree.follows = "import-tree";
    nix-darwin.follows = "nix-darwin";
    nixpkgs.follows = "nixpkgs";
    pi.follows = "pi";
    systems.follows = "systems";
  };
};
```

Import the aggregate once and enable it:

```nix
{
  imports = [ inputs.dendritic-slop.modules.nixos.slop ];

  dendriticSlop = {
    enable = true;
    username = "alice";
    context7ApiKeyFile = "/run/agenix/context7ApiKey";

    # All imported targets are discovered and enabled by default.
    targets.herdr.enable = false;
  };
}
```

Like Stylix, `autoEnable` defaults to `true`. Set `dendriticSlop.autoEnable = false` to opt into targets individually, or disable one through `targets.<name>.enable = false`.

The NixOS aggregate expects Home Manager and impermanence to already be imported; the Darwin aggregate expects Home Manager. This avoids duplicate integrations in existing host compositions. Credentials remain in the consuming flake and are passed only as runtime path strings.

For standalone Home Manager, import `inputs.dendritic-slop.modules.homeManager.slop`, set `dendriticSlop.enable = true`, and configure `dendriticSlop.context7.apiKeyFile` if needed. Individual feature modules can be imported instead of `slop`; each exposes the same global and per-target controls.

## Development

```console
nix fmt
nix flake check --no-eval-cache --no-build --all-systems
```

Third-party inputs are pinned by `flake.lock`. Dependabot groups weekly Nix and GitHub Actions updates; review them rather than auto-merging because skills and extensions execute with the agent's authority. CI checks formatting, evaluates every supported system, and builds native Home Manager plus NixOS or nix-darwin module tests. SemVer tags publish to FlakeHub through short-lived GitHub OIDC credentials.
