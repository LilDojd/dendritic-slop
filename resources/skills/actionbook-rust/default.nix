{ inputs, ... }:
{
  title = "Actionbook Rust skills";
  description = "Rust language, ecosystem, domain, debugging, navigation, and review workflows.";
  homepage = "https://github.com/actionbook/rust-skills";
  source = inputs.actionbook-rust-skills + "/skills";
  collection = true;
  members = [
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
  runtimeInputs = pkgs: [
    pkgs.cargo
    pkgs.rust-analyzer
    pkgs.rustc
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser
  ];
}
