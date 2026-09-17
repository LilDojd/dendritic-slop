{ config, lib, ... }:
let
  apiKeyFileOption = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.addCheck lib.types.str (
        path:
        lib.hasPrefix "/" path && path != builtins.storeDir && !lib.hasPrefix "${builtins.storeDir}/" path
      )
    );
    default = null;
    description = ''
      Absolute runtime path to the decrypted TypeSafe API key, outside the Nix store.
      Read into TYPESAFE_API_KEY when Pi starts, only when the extension is enabled.
    '';
    example = "/run/agenix/typesafe-api-key";
  };

  targetModule =
    { config, ... }:
    let
      cfg = config.dendriticSlop;
      typesafe = cfg.extensions.pi-typesafe;
    in
    {
      options.dendriticSlop.extensions.pi-typesafe.secrets.apiKeyFile = apiKeyFileOption;
      config = lib.mkIf (cfg.enable && typesafe.enable && typesafe.secrets.apiKeyFile != null) {
        programs.pi.coding-agent.environment.TYPESAFE_API_KEY.file = typesafe.secrets.apiKeyFile;
      };
    };

  bridge =
    { config, ... }:
    let
      cfg = config.dendriticSlop;
      path = cfg.extensions.pi-typesafe.secrets.apiKeyFile;
    in
    {
      options.dendriticSlop.extensions.pi-typesafe.secrets.apiKeyFile = apiKeyFileOption;
      config.home-manager.users.${cfg.username}.dendriticSlop.extensions.pi-typesafe.secrets.apiKeyFile =
        lib.mkIf (path != null)
          path;
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.typesafe.imports = [
    config.flake.modules.homeManager.resources
    targetModule
  ];
  flake.modules.nixos.slop = bridge;
  flake.modules.darwin.slop = bridge;
}
