{
  flake.modules.nixos.persistence =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop;
      enabled = cfg.enable && (cfg.targets.persistence.enable or null) != false;
      homeCfg = config.home-manager.users.${cfg.username}.dendriticSlop;
      directories = [
        ".local/state/dendritic-slop"
        ".pi/agent"
      ]
      ++ lib.optional (
        homeCfg.tools.tsk.enable || homeCfg.skills.tsk-cli.enable || homeCfg.herdr.plugins.tsk.enable
      ) ".tsk"
      ++ lib.optional homeCfg.targets.claude.enable ".claude";
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
