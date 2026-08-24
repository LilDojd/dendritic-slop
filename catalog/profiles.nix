{
  core = {
    title = "Core";
    description = "Pi integration, declarative rules, and the core Bro, Herdr, and Jujutsu skills.";
    targets = [
      "git"
      "herdr"
      "pi"
      "rules"
    ];
    members = {
      skills = [
        "bro"
        "herdr"
        "jujutsu"
        "ponytail"
        "ponytail-audit"
        "ponytail-debt"
        "ponytail-gain"
        "ponytail-help"
        "ponytail-review"
      ];
      extensions = [
        "ask-user"
        "herdr-agent-state"
        "pi-mcp-adapter"
      ];
      tools = [
        "herdr"
        "pi"
      ];
    };
  };

  rust = {
    title = "Rust";
    description = "Reviewed Rust language, ecosystem, domain, debugging, navigation, and review skills.";
    members.skills = [
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
      "rust-skills"
      "rust-symbol-analyzer"
      "rust-trait-explorer"
      "unsafe-checker"
    ];
  };

  python = {
    title = "Python";
    description = "Authoritative workflows for uv, Ruff, and ty.";
    members.skills = [
      "ruff"
      "ty"
      "uv"
    ];
  };

  superpowers = {
    title = "Superpowers";
    description = "A complete reviewed software-development workflow.";
    members = {
      extensions = [ "superpowers-bootstrap" ];
      skills = [
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
    };
  };

  web = {
    title = "Web";
    description = "Reviewed web access and local browser automation for Pi.";
    members = {
      extensions = [ "web-access" ];
      mcps = [ "browser" ];
    };
  };
}
