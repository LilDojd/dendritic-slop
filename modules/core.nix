{
  flake.modules.homeManager.core =
    { lib, ... }:
    {
      options.dendriticSlop = {
        enable = lib.mkEnableOption "declarative Pi and LLM tooling";

        autoEnable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Automatically enable every imported dendritic-slop target.";
        };
      };
    };
}
