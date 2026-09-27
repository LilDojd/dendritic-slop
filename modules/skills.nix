{ inputs, lib, ... }:
let
  fromDir = source: names: lib.genAttrs names (name: "${source}/${name}");

  rust =
    fromDir "${inputs.actionbook-rust-skills}/skills" [
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
    ]
    // {
      rust-skills = "${inputs.leonardomso-rust-skills}";
    };

  python = fromDir "${inputs.astral-agent-skills}/plugins/astral/skills" [
    "ruff"
    "ty"
    "uv"
  ];

  pydanticSkills = fromDir "${inputs.pydantic-skills}/skills";

  pydantic = pydanticSkills [
    "building-pydantic-ai-agents"
    "logfire-evals"
    "logfire-infrastructure"
    "logfire-instrumentation"
    "logfire-query"
    "logfire-setup"
    "logfire-ui"
    "pydantic"
    "pydantic-ai-harness"
  ];

  pydanticMigrations = pydanticSkills [
    "migrating-agno-to-pydantic-ai"
    "migrating-claude-agent-sdk-to-pydantic-ai"
    "migrating-google-adk-to-pydantic-ai"
    "migrating-langchain-to-pydantic-ai"
    "migrating-mastra-to-pydantic-ai"
    "migrating-openai-agents-sdk-to-pydantic-ai"
    "migrating-pi-to-pydantic-ai"
    "migrating-vercel-ai-sdk-and-eve-to-pydantic-ai"
  ];

  ponytail = fromDir "${inputs.ponytail}/skills" [
    "ponytail"
    "ponytail-audit"
    "ponytail-debt"
    "ponytail-gain"
    "ponytail-help"
    "ponytail-review"
  ];

  core = ponytail // {
    bro = ../resources/skills/bro;
    jujutsu = ../resources/skills/jujutsu;
  };

  extra = {
    frontend-design = "${inputs.claude-plugins-official}/plugins/frontend-design/skills/frontend-design";
    tsk-cli = "${inputs.tsk}/skills/tsk-cli";
    uncomplect = "${inputs.joelhooks-skills}/skills/uncomplect";
  };
in
{
  flake = {
    skills = core // rust // python // pydantic // pydanticMigrations // extra;
    skillSets = {
      inherit
        core
        rust
        python
        pydantic
        ;
    };
  };
}
