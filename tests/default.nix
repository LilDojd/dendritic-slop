args:
let
  fixtures = import ./fixtures.nix args;
in
import ./selection.nix fixtures
// import ./skills.nix fixtures
// import ./packages.nix fixtures
// import ./browser.nix fixtures
// import ./firstmate.nix fixtures
// import ./mcp.nix fixtures
// import ./herdr.nix fixtures
// import ./integration.nix fixtures
