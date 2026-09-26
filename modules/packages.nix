{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      narumitw =
        pname:
        pkgs.callPackage ../packages/narumitw-extension.nix {
          source = inputs.narumitw-pi-extensions;
          inherit pname;
        };
      tsk = pkgs.callPackage ../packages/tsk.nix { inherit (inputs) tsk; };
      jj-workspace = pkgs.callPackage ../packages/jj-workspace.nix {
        source = inputs.herdr-plugin-jj-workspace;
      };
    in
    {
      packages = {
        inherit tsk;
        jevons = pkgs.callPackage ../packages/jevons.nix { source = inputs.jevons; };
        pi-ask-user = pkgs.callPackage ../packages/pi-ask-user.nix { source = inputs.pi-ask-user; };
        pi-goal = narumitw "pi-goal";
        pi-jev-compact = pkgs.callPackage ../packages/pi-jev-compact.nix {
          source = inputs.pi-jev-compact;
        };
        pi-mcp-adapter = pkgs.callPackage ../packages/pi-mcp-adapter.nix {
          source = inputs.pi-mcp-adapter;
        };
        pi-playwright = pkgs.callPackage ../packages/pi-playwright.nix { };
        pi-starship = narumitw "pi-starship";
        pi-web-access = pkgs.callPackage ../packages/pi-web-access.nix { source = inputs.pi-web-access; };
        herdr-plugin-jj-workspace = pkgs.callPackage ../packages/herdr-plugin.nix {
          package = jj-workspace;
          source = inputs.herdr-plugin-jj-workspace;
          executable = "jj-workspace";
          executablePath = "target/release/jj-workspace";
        };
        herdr-plugin-tsk = pkgs.callPackage ../packages/herdr-plugin.nix {
          package = tsk;
          source = inputs.tsk;
          executable = "tsk";
          executablePath = "target/release/tsk";
          supportPaths = [
            "scripts/open-board.sh"
            "scripts/open-capture.sh"
          ];
        };
      };
    };
}
