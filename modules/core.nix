{
  flake.modules.homeManager.core =
    { lib, ... }:
    {
      options.dendriticSlop.enable = lib.mkEnableOption "declarative Pi and LLM tooling";
    };
}
