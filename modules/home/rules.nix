{
  flake.modules.homeManager.rules =
    let
      rules = builtins.readFile ../../resources/rules/context.md;
    in
    {
      programs.claude-code.context = rules;
      programs.pi.coding-agent.rules = rules;
    };
}
