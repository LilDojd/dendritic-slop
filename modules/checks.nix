{
  config,
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, self', ... }:
    {
      checks.home =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            config.flake.modules.homeManager.default
            (
              { config, ... }:
              {
                _module.args.osConfig = { };
                home = {
                  username = "slop";
                  homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/slop" else "/home/slop";
                  stateVersion = config.home.version.release;
                };
                programs = {
                  claude-code.enable = true;
                  pi.coding-agent.enable = true;
                  mcp = {
                    enable = true;
                    servers.context7 = {
                      url = "https://mcp.context7.com/mcp";
                      headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
                    };
                  };
                };
                dendriticSlop = {
                  skills = self.skills;
                  piPackages = [ self'.packages.pi-ask-user ];
                  mcpHeaderSecrets.context7.CONTEXT7_API_KEY = "/run/secrets/context7";
                  herdr = {
                    enable = true;
                    plugins = [
                      self'.packages.herdr-plugin-jj-workspace
                      self'.packages.herdr-plugin-tsk
                    ];
                    settings.keys.command = [
                      {
                        key = "prefix+t";
                        type = "plugin_action";
                        command = "herdr-tsk.open-board";
                        description = "Open tsk board";
                      }
                    ];
                  };
                };
              }
            )
          ];
        }).activationPackage;
    };
}
