{ inputs }:
let
  inherit (builtins) listToAttrs map;

  runtime = package: executable: { inherit package executable; };
  shellRuntime = [
    (runtime (pkgs: pkgs.bash) "bash")
    (runtime (pkgs: pkgs.coreutils) "env")
  ];
  browserLauncher =
    pkgs:
    if pkgs.stdenv.hostPlatform.isLinux then
      pkgs.symlinkJoin {
        name = "superpowers-browser-launcher";
        paths = [ pkgs.xdg-utils ];
        postBuild = ''
          ln -s xdg-open "$out/bin/open"
        '';
      }
    else
      pkgs.symlinkJoin {
        name = "superpowers-browser-launcher";
        paths = [
          (pkgs.writeShellScriptBin "open" ''
            exec /usr/bin/open "$@"
          '')
        ];
        postBuild = ''
          ln -s open "$out/bin/xdg-open"
        '';
      };
  named = name: value: {
    inherit name value;
  };

  actionbookLeaves = [
    "coding-guidelines"
    "domain-cli"
    "domain-cloud-native"
    "domain-embedded"
    "domain-fintech"
    "domain-iot"
    "domain-ml"
    "domain-web"
    "m01-ownership"
    "m02-resource"
    "m03-mutability"
    "m04-zero-cost"
    "m05-type-driven"
    "m06-error-handling"
    "m07-concurrency"
    "m09-domain"
    "m10-performance"
    "m11-ecosystem"
    "m12-lifecycle"
    "m13-domain-error"
    "m14-mental-model"
    "m15-anti-pattern"
    "meta-cognition-parallel"
    "rust-call-graph"
    "rust-code-navigator"
    "rust-daily"
    "rust-deps-visualizer"
    "rust-learner"
    "rust-refactor-helper"
    "rust-router"
    "rust-skill-creator"
    "rust-symbol-analyzer"
    "rust-trait-explorer"
    "unsafe-checker"
  ];
  cargoLeaves = [
    "domain-embedded"
    "m10-performance"
    "m11-ecosystem"
    "m15-anti-pattern"
    "rust-deps-visualizer"
    "rust-learner"
    "rust-router"
    "unsafe-checker"
  ];
  browserLeaves = [
    "rust-daily"
    "rust-learner"
    "rust-skill-creator"
  ];
  lspLeaves = [
    "rust-call-graph"
    "rust-code-navigator"
    "rust-refactor-helper"
    "rust-symbol-analyzer"
    "rust-trait-explorer"
  ];
  actionbookRuntime =
    name:
    (if builtins.elem name cargoLeaves then [ (runtime (pkgs: pkgs.cargo) "cargo") ] else [ ])
    ++ (
      if builtins.elem name lspLeaves then
        [ (runtime (pkgs: pkgs.rust-analyzer) "rust-analyzer") ]
      else
        [ ]
    )
    ++ (if name == "rust-router" then [ (runtime (pkgs: pkgs.rustc) "rustc") ] else [ ])
    ++ (
      if builtins.elem name browserLeaves then
        [
          (runtime (
            pkgs: inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser
          ) "agent-browser")
        ]
      else
        [ ]
    );
  actionbook = listToAttrs (
    map (
      name:
      named name {
        title = name;
        description = "Reviewed Actionbook Rust skill: ${name}.";
        homepage = "https://github.com/actionbook/rust-skills";
        repository = "actionbook-rust";
        repositoryPath = "skills/${name}";
        profiles = [ "rust" ];
        defaultEnable = true;
        runtimeExecutables = actionbookRuntime name;
        capabilities = {
          executesCode = actionbookRuntime name != [ ];
          network = builtins.elem name browserLeaves;
        };
        requiresHarnessCapabilities =
          (
            if
              builtins.elem name [
                "meta-cognition-parallel"
                "rust-daily"
                "rust-learner"
              ]
            then
              [ "subagents" ]
            else
              [ ]
          )
          ++ (if builtins.elem name lspLeaves then [ "lsp" ] else [ ]);
      }
    ) actionbookLeaves
  );

  astral = listToAttrs (
    map
      (
        name:
        named name {
          title = name;
          description = "Reviewed Astral workflow for ${name}.";
          homepage = "https://github.com/astral-sh/claude-code-plugins";
          repository = "astral-python";
          repositoryPath = "plugins/astral/skills/${name}";
          profiles = [ "python" ];
          defaultEnable = true;
          capabilities.executesCode = true;
          runtimeExecutables = [ (runtime (pkgs: pkgs.${name}) name) ];
        }
      )
      [
        "ruff"
        "ty"
        "uv"
      ]
  );

  superpowersLeaves = [
    "brainstorming"
    "dispatching-parallel-agents"
    "executing-plans"
    "finishing-a-development-branch"
    "receiving-code-review"
    "requesting-code-review"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "using-git-worktrees"
    "using-superpowers"
    "verification-before-completion"
    "writing-plans"
    "writing-skills"
  ];
  superpowersRuntime =
    name:
    if name == "brainstorming" then
      shellRuntime
      ++ [
        (runtime (pkgs: pkgs.gnugrep) "grep")
        (runtime (pkgs: pkgs.gnused) "sed")
        (runtime (pkgs: pkgs.nodejs_24) "node")
        (runtime (pkgs: if pkgs.stdenv.hostPlatform.isLinux then pkgs.procps else pkgs.ps) "ps")
        (runtime browserLauncher "open")
        (runtime browserLauncher "xdg-open")
      ]
    else if name == "subagent-driven-development" then
      shellRuntime
      ++ [
        (runtime (pkgs: pkgs.gawk) "awk")
        (runtime (pkgs: pkgs.gitMinimal) "git")
      ]
    else if name == "systematic-debugging" then
      shellRuntime
      ++ [
        (runtime (pkgs: pkgs.findutils) "find")
        (runtime (pkgs: pkgs.nodejs_24) "npm")
      ]
    else if
      builtins.elem name [
        "executing-plans"
        "finishing-a-development-branch"
        "requesting-code-review"
        "using-git-worktrees"
      ]
    then
      [ (runtime (pkgs: pkgs.gitMinimal) "git") ]
    else
      [ ];
  superpowers = listToAttrs (
    map (
      name:
      named name {
        title = name;
        description = "Reviewed Superpowers workflow: ${name}.";
        homepage = "https://github.com/obra/superpowers";
        repository = "superpowers";
        repositoryPath = "skills/${name}";
        profiles = [ "superpowers" ];
        defaultEnable = false;
        runtimeExecutables = superpowersRuntime name;
        capabilities = {
          executesCode = superpowersRuntime name != [ ];
          network = name == "brainstorming";
          mutatesUserConfig = name == "subagent-driven-development";
        };
        requiresHarnessCapabilities =
          if
            builtins.elem name [
              "dispatching-parallel-agents"
              "requesting-code-review"
              "subagent-driven-development"
            ]
          then
            [ "subagents" ]
          else
            [ ];
        compatibilityTargets = [ "pi" ];
      }
    ) superpowersLeaves
  );
in
actionbook
// astral
// superpowers
// {
  bro = {
    title = "Bro";
    description = "Restate the previous response in plain human language.";
    source = ../resources/skills/bro/SKILL.md;
    profiles = [ "core" ];
    defaultEnable = true;
  };

  herdr = {
    title = "Herdr";
    description = "Inspect and control Herdr workspaces, tabs, panes, commands, and agents.";
    homepage = "https://github.com/herdrdev/herdr";
    source = inputs.herdr-src + "/skills/herdr/SKILL.md";
    profiles = [ "core" ];
    defaultEnable = true;
    requiresTargets = [ "herdr" ];
  };

  jujutsu = {
    title = "Jujutsu";
    description = "Manage Jujutsu repositories and colocated Git state with non-interactive workflows.";
    source = ../resources/skills/jujutsu/SKILL.md;
    profiles = [ "core" ];
    defaultEnable = true;
    capabilities.executesCode = true;
    runtimeExecutables = [ (runtime (pkgs: pkgs.jujutsu) "jj") ];
  };

  ponytail = {
    title = "Ponytail";
    description = "Choose the simplest safe solution that satisfies the coding task.";
    homepage = "https://github.com/DietrichGebert/ponytail";
    repository = "ponytail";
    repositoryPath = "skills/ponytail";
    profiles = [ "core" ];
    defaultEnable = true;
  };

  ponytail-audit = {
    title = "Ponytail audit";
    description = "Identify over-engineering across a repository without changing it.";
    homepage = "https://github.com/DietrichGebert/ponytail";
    repository = "ponytail";
    repositoryPath = "skills/ponytail-audit";
    profiles = [ "core" ];
    defaultEnable = true;
  };

  ponytail-debt = {
    title = "Ponytail debt";
    description = "Report deliberate Ponytail shortcuts and their upgrade triggers.";
    homepage = "https://github.com/DietrichGebert/ponytail";
    repository = "ponytail";
    repositoryPath = "skills/ponytail-debt";
    profiles = [ "core" ];
    defaultEnable = true;
  };

  ponytail-gain = {
    title = "Ponytail gain";
    description = "Display Ponytail's published benchmark impact summary.";
    homepage = "https://github.com/DietrichGebert/ponytail";
    repository = "ponytail";
    repositoryPath = "skills/ponytail-gain";
    profiles = [ "core" ];
    defaultEnable = true;
  };

  ponytail-help = {
    title = "Ponytail help";
    description = "Display a quick reference for Ponytail modes and skills.";
    homepage = "https://github.com/DietrichGebert/ponytail";
    repository = "ponytail";
    repositoryPath = "skills/ponytail-help";
    profiles = [ "core" ];
    defaultEnable = true;
  };

  ponytail-review = {
    title = "Ponytail review";
    description = "Review a diff for unnecessary complexity without applying changes.";
    homepage = "https://github.com/DietrichGebert/ponytail";
    repository = "ponytail";
    repositoryPath = "skills/ponytail-review";
    profiles = [ "core" ];
    defaultEnable = true;
  };

  rust-skills = {
    title = "Rust skills";
    description = "Comprehensive, source-linked Rust coding guidelines and best practices.";
    homepage = "https://github.com/leonardomso/rust-skills";
    repository = "leonardomso-rust-skills";
    repositoryPath = ".";
    profiles = [ "rust" ];
    defaultEnable = true;
  };
}
