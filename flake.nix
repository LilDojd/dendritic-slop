{
  description = "Dendritic Nix modules for Pi and LLM tooling";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    astral-agent-skills = {
      url = "github:astral-sh/claude-code-plugins";
      flake = false;
    };

    actionbook-rust-skills = {
      url = "github:actionbook/rust-skills";
      flake = false;
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    herdr-plugin-jj-workspace = {
      url = "github:NathanFlurry/herdr-plugin-jj-workspace";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    jevons = {
      url = "github:LilDojd/jevons";
      flake = false;
    };

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

    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };

    pi-ask-user = {
      url = "github:edlsh/pi-ask-user";
      flake = false;
    };

    pi-mcp-adapter = {
      url = "github:nicobailon/pi-mcp-adapter";
      flake = false;
    };

    pi-web-access = {
      url = "github:nicobailon/pi-web-access";
      flake = false;
    };

    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./modules) ];
    };
}
