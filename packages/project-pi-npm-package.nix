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
  removeHostDevRecords =
    path: record:
    !(
      lib.hasPrefix "node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/" path
      && (record.integrity or "") == ""
    );
  projectDependencies = dependencies: builtins.removeAttrs dependencies removeDependencies;
  projectRoot =
    root:
    root
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
    packages = lib.filterAttrs removeHostDevRecords (
      packageLock.packages
      // {
        "" = projectRoot packageLock.packages."";
      }
    );
  };
}
