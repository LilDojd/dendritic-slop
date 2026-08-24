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
      url = "github:astral-sh/claude-code-plugins/f3ce88a7ba830f53afd6d944c1d0278ed318e142";
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

    impermanence.url = "github:nix-community/impermanence";

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

    pi-ask-user = {
      url = "github:edlsh/pi-ask-user/2de7e145227f7a527e995e323a50e7ee9bf88b0e";
      flake = false;
    };

    pi-mcp-adapter = {
      url = "github:nicobailon/pi-mcp-adapter/6c08147f7a3c6eba670fa8fb73e1fe68a7ab471f";
      flake = false;
    };

    pi-web-access = {
      url = "github:nicobailon/pi-web-access/846949c645efadd6314f25eef60b390b0669704a";
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
