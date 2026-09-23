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

  anthropic-claude-plugins = {
    input = "claude-plugins-official";
    source = inputs.claude-plugins-official;
    homepage = "https://github.com/anthropics/claude-plugins-official";
    license = "Apache-2.0";
    licenseEvidence = [ (inputs.claude-plugins-official + "/plugins/frontend-design/LICENSE") ];

    exportedLeaves = [ "frontend-design" ];
    supportPaths = [ "plugins/frontend-design/LICENSE" ];
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

}
