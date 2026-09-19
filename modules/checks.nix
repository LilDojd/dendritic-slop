{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem = { pkgs, system, ... }: {
    checks = import ../tests {
      inherit
        config
        inputs
        lib
        pkgs
        system
        ;
    };
    formatter = pkgs.nixfmt-tree;
  };
}
