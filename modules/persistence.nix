{
  flake.modules.nixos.persistence =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop;
      enabled = cfg.enable && (cfg.targets.persistence.enable or null) != false;
    in
    {
      config = lib.mkIf enabled {
        environment.persistence."/persistent".users.${cfg.username}.directories = [
          ".pi/agent"
        ];
      };
    };
}
