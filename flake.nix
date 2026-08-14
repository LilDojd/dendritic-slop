{
  description = "Dendritic Nix modules for Pi and LLM tooling";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    actionbook-rust-skills = {
      url = "github:actionbook/rust-skills";
      flake = false;
    };

    flake-parts = {
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    herdr-src = {
      url = "github:herdrdev/herdr";
      flake = false;
    };

    herdr-plugin-jj-workspace = {
      url = "github:NathanFlurry/herdr-plugin-jj-workspace/a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "https://flakehub.com/f/nix-community/impermanence/0.1.*";

    import-tree.url = "github:denful/import-tree";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    leonardomso-rust-skills = {
      url = "github:leonardomso/rust-skills";
      flake = false;
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };

    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./modules) ];
    };
}
