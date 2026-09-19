{
  flake.modules.nixos.persistence =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop;
      enabled = cfg.enable && (cfg.targets.persistence.enable or null) != false;
      directories = [
        ".local/state/dendritic-slop"
        ".pi/agent"
      ]
      ++ lib.optionals (cfg.tools.firstmate.enable == true) [
        ".local/share/firstmate"
        ".treehouse"
      ];
    in
    {
      config = lib.mkIf enabled {
        environment.persistence."/persistent".users.${cfg.username}.directories = directories;
        # Otherwise a new bind mount can hide files just installed by activation.
        systemd.services."home-manager-${cfg.username}".unitConfig.RequiresMountsFor = map (
          directory: "${config.users.users.${cfg.username}.home}/${directory}"
        ) directories;
      };
    };
}
