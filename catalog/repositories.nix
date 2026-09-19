{ inputs }:
{
  actionbook-rust = {
    input = "actionbook-rust-skills";
    source = inputs.actionbook-rust-skills;
    homepage = "https://github.com/actionbook/rust-skills";
    license = "MIT";
    licenseEvidence = [
      (inputs.actionbook-rust-skills + "/metadata.json")
      (inputs.actionbook-rust-skills + "/README.md")
    ];

    exportedLeaves = [
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
    ignoredLeaves = [
      "core-actionbook"
      "core-agent-browser"
      "core-dynamic-skills"
      "core-fix-skill-docs"
    ];
    supportPaths = [
      "_meta"
      "agents"
      "metadata.json"
      "README.md"
    ];
  };

  astral-python = {
    input = "astral-agent-skills";
    source = inputs.astral-agent-skills;
    homepage = "https://github.com/astral-sh/claude-code-plugins";
    license = "Apache-2.0 OR MIT";
    licenseEvidence = [
      (inputs.astral-agent-skills + "/LICENSE-APACHE")
      (inputs.astral-agent-skills + "/LICENSE-MIT")
    ];

    exportedLeaves = [
      "ruff"
      "ty"
      "uv"
    ];
    supportPaths = [
      "LICENSE-APACHE"
      "LICENSE-MIT"
    ];
  };

  leonardomso-rust-skills = {
    input = "leonardomso-rust-skills";
    source = inputs.leonardomso-rust-skills;
    homepage = "https://github.com/leonardomso/rust-skills";
    license = "MIT";
    licenseEvidence = [ (inputs.leonardomso-rust-skills + "/LICENSE") ];

    exportedLeaves = [ "rust-skills" ];
    supportPaths = [
      "LICENSE"
      "rules"
      "SKILL.md"
    ];
  };

  ponytail = {
    input = "ponytail";
    source = inputs.ponytail;
    homepage = "https://github.com/DietrichGebert/ponytail";
    license = "MIT";
    licenseEvidence = [ (inputs.ponytail + "/LICENSE") ];

    exportedLeaves = [
      "ponytail"
      "ponytail-audit"
      "ponytail-debt"
      "ponytail-gain"
      "ponytail-help"
      "ponytail-review"
    ];
    supportPaths = [ "LICENSE" ];
  };

  superpowers = {
    input = "superpowers";
    source = inputs.superpowers;
    homepage = "https://github.com/obra/superpowers";
    license = "MIT";
    licenseEvidence = [ (inputs.superpowers + "/LICENSE") ];

    exportedLeaves = [
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
    supportPaths = [
      ".pi/extensions/superpowers.ts"
      "LICENSE"
      "package.json"
    ];
    entrypoints = [
      {
        path = ".pi/extensions/superpowers.ts";
        type = "interpreter";
        interpreter = "pi";
        owner = "using-superpowers";
      }
      {
        path = "skills/brainstorming/scripts/helper.js";
        type = "interpreter";
        interpreter = "browser";
        owner = "brainstorming";
      }
      {
        path = "skills/brainstorming/scripts/server.cjs";
        type = "interpreter";
        interpreter = "node";
        owner = "brainstorming";
      }
      {
        path = "skills/brainstorming/scripts/start-server.sh";
        type = "executable";
        owner = "brainstorming";
      }
      {
        path = "skills/brainstorming/scripts/stop-server.sh";
        type = "executable";
        owner = "brainstorming";
      }
      {
        path = "skills/subagent-driven-development/scripts/review-package";
        type = "executable";
        owner = "subagent-driven-development";
      }
      {
        path = "skills/subagent-driven-development/scripts/sdd-workspace";
        type = "executable";
        owner = "subagent-driven-development";
      }
      {
        path = "skills/subagent-driven-development/scripts/task-brief";
        type = "executable";
        owner = "subagent-driven-development";
      }
      {
        path = "skills/systematic-debugging/find-polluter.sh";
        type = "executable";
        owner = "systematic-debugging";
      }
    ];
    ignoredEntrypoints = [ "skills/writing-skills/render-graphs.js" ];
    patches = [
      ./patches/superpowers-no-resource-discovery.patch
      ./patches/superpowers-writing-skills-no-render.patch
    ];
    buildInputs = [
      (pkgs: pkgs.makeWrapper)
      (pkgs: pkgs.patch)
    ];
  };
}
