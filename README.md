# dendritic-slop

Declarative Pi and LLM tooling for NixOS and nix-darwin.

Features are exported as `modules.<class>.<aspect>` flake-parts modules following the [Dendritic pattern](https://dendrix.denful.dev/Dendritic.html).

## Resources

Home Manager modules:

- `pi` — Pi and the pinned MCP adapter
- `context7` — the Context7 MCP server with an optional API-key file
- `herdr` — Herdr and opt-in Herdr plugins
- `resources` — individually selectable Pi skills and extensions, including the Herdr skill and Pi integration
- `git` — adds `.mcp.json` and `mcp.json` to the global Git ignore list
- `rules` — Pi instructions for declarative global tooling and Herdr agent selection
- `slop` — the aggregate Home Manager module

System modules:

- `nixos.slop` — configures the Home Manager aggregate and persists Pi state
- `darwin.slop` — configures the Home Manager aggregate
- `nixos.persistence` — persists `.pi/agent`

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

    profiles = {
      core.enable = true;
      rust.enable = true;
      python.enable = true;
    };
    migrations.globalSkills.takeOver = true;

    # Explicit leaf exceptions and opt-ins override profile defaults.
    herdr.plugins.jj-workspace.enable = true;
    skills.ty.enable = false;
    extensions.web-access.enable = true;
  };
}
```

Resources and targets are disabled unless selected by an explicit profile or leaf setting. Profile members use module defaults, so explicit `targets.<name>.enable`, `skills.<name>.enable`, `extensions.<name>.enable`, and `herdr.plugins.<name>.enable` values win.

`web-access` is opt-in because it accesses the network and processes untrusted remote content. Its default configuration denies browser-cookie access and remote hosted extraction and keeps SSRF protection enabled. Herdr plugins are opt-in because they execute as the user. Enabling a plugin registers the pinned build with Herdr; disabling it removes the registration only while dendritic-slop still owns it. Manually managed registrations are left unchanged.

The NixOS aggregate persists `.pi/agent` and `.local/state/dendritic-slop` unless `dendriticSlop.targets.persistence.enable = false`.

The Jujutsu workspace plugin exposes `new` and `new-tab` actions for creating a Jujutsu workspace as a Herdr workspace or tab. Its wizard runs `jj git fetch` before creation; fetch failure is nonfatal. New workspaces are based on `trunk()` by default and receive a matching bookmark. Set `JJ_BASE_REV` or `JJ_WORKSPACE_ROOT` in the plugin config directory's `.env` file to override the base revision or checkout root. The `remove` action runs `jj workspace forget`, deletes the focused secondary workspace directory, and closes its Herdr workspace.

Consumers of `nixos.slop` must import Home Manager and impermanence; consumers of `darwin.slop` must import Home Manager. Store credentials outside the Nix store and pass only absolute runtime paths to secret files.

For standalone Home Manager, import `inputs.dendritic-slop.modules.homeManager.slop`, set `dendriticSlop.enable = true`, and configure `dendriticSlop.context7.apiKeyFile` if needed. Individual feature modules can be imported instead of `slop`; each exposes `dendriticSlop.enable` and its own feature options.

## Development

```console
nix fmt
nix flake check --no-eval-cache --no-build --all-systems
```

The [resource catalog](https://lildojd.github.io/dendritic-slop/) lists each resource's option, activation default, version where applicable, definition, homepage, and target dependency.

Third-party inputs and Pi packages are pinned. Renovate opens weekly grouped updates for GitHub Actions, Nix inputs, and pinned Pi npm packages; executable Herdr plugin inputs remain in a separate group. Review executable resource updates before merging because skills, extensions, and Herdr plugins run with the user or agent's authority. CI validates formatting, skills, generated documentation, opt-in defaults, Herdr plugin packaging and activation, all supported systems, and native Home Manager, NixOS, and nix-darwin modules. SemVer tags publish to FlakeHub using GitHub OIDC credentials.
