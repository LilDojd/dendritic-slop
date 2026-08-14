{ inputs }:
rec {
  title = "Jujutsu workspace";
  description = "Create Jujutsu workspaces as Herdr workspaces or tabs and remove focused secondary workspaces.";
  homepage = "https://github.com/NathanFlurry/herdr-plugin-jj-workspace";
  id = "nathanflurry.jj-workspace";
  version = "0.1.0";
  actions = [
    "new — create and open a Jujutsu workspace as a Herdr workspace"
    "new-tab — create and open a Jujutsu workspace as a tab"
    "remove — forget the focused secondary Jujutsu workspace, delete its directory, and close its Herdr workspace"
  ];

  package =
    pkgs:
    pkgs.rustPlatform.buildRustPackage {
      pname = "herdr-plugin-jj-workspace";
      inherit version;
      src = inputs.herdr-plugin-jj-workspace;

      cargoLock.lockFile = inputs.herdr-plugin-jj-workspace + "/Cargo.lock";
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postFixup = ''
        wrapProgram "$out/bin/jj-workspace" \
          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.jujutsu ]}
      '';

      meta = {
        inherit homepage;
        description = "Create Jujutsu workspaces from Herdr";
        license = pkgs.lib.licenses.mit;
        mainProgram = "jj-workspace";
        platforms = pkgs.lib.platforms.linux ++ pkgs.lib.platforms.darwin;
      };
    };

  pluginRoot =
    pkgs:
    let
      binary = package pkgs;
      manifest = pkgs.writeText "herdr-plugin.toml" ''
        id = "nathanflurry.jj-workspace"
        name = "jj workspaces"
        version = "0.1.0"
        min_herdr_version = "0.7.0"
        description = "Create Jujutsu workspaces as Herdr workspaces or tabs."
        platforms = ["linux", "macos"]

        [[actions]]
        id = "new"
        title = "New jj workspace"
        contexts = ["workspace", "global"]
        command = ["target/release/jj-workspace", "open", "workspace"]

        [[actions]]
        id = "new-tab"
        title = "New jj workspace (in tab)"
        contexts = ["workspace", "global"]
        command = ["target/release/jj-workspace", "open", "tab"]

        [[actions]]
        id = "remove"
        title = "Remove jj workspace"
        contexts = ["workspace"]
        command = ["target/release/jj-workspace", "remove"]

        [[panes]]
        id = "wizard"
        title = "New jj workspace"
        placement = "overlay"
        command = ["target/release/jj-workspace", "wizard"]
      '';
    in
    pkgs.runCommand "herdr-plugin-jj-workspace-${version}" { } ''
      mkdir -p "$out/target/release"
      cp ${manifest} "$out/herdr-plugin.toml"
      ln -s ${binary}/bin/jj-workspace "$out/target/release/jj-workspace"
    '';
}
