{ inputs, ... }:
{
  title = "Superpowers";
  description = "A complete software-development workflow covering design, planning, implementation, review, debugging, and verification.";
  homepage = "https://github.com/obra/superpowers";
  source = inputs.superpowers + "/skills";
  collection = true;
  defaultEnable = false;
  members = [
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
  extraFiles = [ (inputs.superpowers + "/LICENSE") ];
  runtimeInputs = pkgs: [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gitMinimal
    pkgs.gnugrep
    pkgs.gnused
    pkgs.graphviz
    pkgs.nodejs_24
  ];
}
