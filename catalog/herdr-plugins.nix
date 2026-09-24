{ inputs }:
let
  source = inputs.herdr-plugin-jj-workspace;
  manifest = builtins.fromTOML (builtins.readFile (source + "/herdr-plugin.toml"));
  packageManifest = builtins.fromTOML (builtins.readFile (source + "/Cargo.toml"));
in
{
  tsk =
    let
      manifest = builtins.fromTOML (builtins.readFile (inputs.tsk + "/herdr-plugin.toml"));
    in
    {
      title = "tsk";
      description = "Open the shared task board and quick capture in Herdr.";
      homepage = "https://github.com/smarzban/tsk";
      requiresTargets = [ "herdr" ];
      capabilities = {
        executesCode = true;
        network = true;
      };
      source = inputs.tsk;
      pluginId = manifest.id;
      inherit (manifest) version;
      minimumHerdrVersion = manifest.min_herdr_version;
      executable = "tsk";
      executablePath = "target/release/tsk";
      supportPaths = [
        "scripts/open-board.sh"
        "scripts/open-capture.sh"
      ];
      actions = map (action: { inherit (action) id title; }) manifest.actions;
      keybindings = [
        {
          key = "prefix+t";
          command = "${manifest.id}.open-board";
          description = "Open tsk board";
        }
      ];
      package = pkgs: pkgs.callPackage ../packages/tsk.nix { inherit (inputs) tsk; };
    };

  jj-workspace = {
    title = "Jujutsu workspace";
    description = "Create, open, and remove Jujutsu workspaces from Herdr.";
    homepage = "https://github.com/NathanFlurry/herdr-plugin-jj-workspace";

    requiresTargets = [ "herdr" ];
    capabilities = {
      executesCode = true;
      mutatesUserConfig = true;
    };
    inherit source;
    pluginId = manifest.id;
    version = manifest.version;
    minimumHerdrVersion = manifest.min_herdr_version;
    executable = "jj-workspace";
    executablePath = "target/release/jj-workspace";
    actions = map (action: {
      inherit (action) id title;
    }) manifest.actions;
    keybindings = [
      {
        key = "prefix+a";
        command = "${manifest.id}.new-tab";
        description = "New jj workspace in a tab";
      }
      {
        key = "prefix+shift+a";
        command = "${manifest.id}.new";
        description = "New jj workspace";
      }
      {
        key = "prefix+d";
        command = "${manifest.id}.remove";
        description = "Remove jj workspace";
      }
    ];

    package =
      pkgs:
      pkgs.rustPlatform.buildRustPackage {
        pname = "herdr-plugin-jj-workspace";
        version = packageManifest.package.version;
        src = source;

        cargoLock.lockFile = source + "/Cargo.lock";
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postFixup = ''
          wrapProgram "$out/bin/jj-workspace" \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.jujutsu ]}
        '';

        meta = {
          homepage = "https://github.com/NathanFlurry/herdr-plugin-jj-workspace";
          description = "Create Jujutsu workspaces from Herdr";
          license = pkgs.lib.licenses.mit;
          mainProgram = "jj-workspace";
          platforms = pkgs.lib.platforms.linux ++ pkgs.lib.platforms.darwin;
        };
      };
  };
}
