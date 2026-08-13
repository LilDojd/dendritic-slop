{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  systems = builtins.filter (system: system != "x86_64-darwin") (import inputs.systems);
}
