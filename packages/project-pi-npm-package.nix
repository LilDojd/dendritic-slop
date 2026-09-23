{ lib }:
{
  source,
  hostPeers,
  removeDependencies ? [ ],
}:
let
  package = builtins.fromJSON (builtins.readFile (source + "/package.json"));
  packageLock = builtins.fromJSON (builtins.readFile (source + "/package-lock.json"));
  hostPeerMeta = lib.mapAttrs (_: _: { optional = true; }) hostPeers;
  hostPeerRecords = map (name: "node_modules/${name}") (builtins.attrNames hostPeers);
  # Only production dependencies are installed, and Pi provides its host peers.
  keepRecord = path: record: !(record.dev or false) && !builtins.elem path hostPeerRecords;
  projectDependencies = dependencies: builtins.removeAttrs dependencies removeDependencies;
  projectRoot =
    root:
    builtins.removeAttrs root [ "devDependencies" ]
    // {
      dependencies = projectDependencies (root.dependencies or { });
      peerDependencies = (root.peerDependencies or { }) // hostPeers;
      peerDependenciesMeta = (root.peerDependenciesMeta or { }) // hostPeerMeta;
    };
in
{
  package = projectRoot package // {
    pi = {
      extensions = [ "./index.ts" ];
      skills = [ ];
    };
  };
  packageLock = packageLock // {
    packages = lib.filterAttrs keepRecord packageLock.packages // {
      "" = projectRoot packageLock.packages."";
    };
  };
}
