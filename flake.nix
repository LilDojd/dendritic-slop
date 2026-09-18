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

    herdr-plugin-jj-workspace = {
      url = "github:NathanFlurry/herdr-plugin-jj-workspace/a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    jevons = {
      url = "github:LilDojd/jevons/0e7a9d59618b2ca884082cd31270497b6126b78d";
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
      url = "github:DietrichGebert/ponytail/356918eba965ee1eac64bd3a7f0dd02108350de5";
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
      url = "github:edlsh/pi-ask-user/705fdc60eaea5b9588f3aa6a6cb6a577516b17af";
      flake = false;
    };

    pi-mcp-adapter = {
      url = "github:nicobailon/pi-mcp-adapter/23c28529083a369f704d036fb8231c590f41ea80";
      flake = false;
    };

    pi-playwright = {
      url = "https://registry.npmjs.org/@lebronj/pi-playwright/-/pi-playwright-0.0.1.tgz";
      flake = false;
    };

    pi-web-access = {
      url = "github:nicobailon/pi-web-access/192ac1875e3b8f88c78953dbc314949ec9fcaa27";
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
