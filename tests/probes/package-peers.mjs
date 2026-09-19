import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const [root, expectedPeersJson] = process.argv.slice(2);
const manifest = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const expectedPeers = JSON.parse(expectedPeersJson);
const dependencies = manifest.dependencies ?? {};
const peers = manifest.peerDependencies ?? {};
const peerMeta = manifest.peerDependenciesMeta ?? {};

for (const name of Object.keys(expectedPeers)) {
  if (peers[name] !== "*") throw new Error("non-wildcard Pi host peer: " + name);
  if (peerMeta[name]?.optional !== true) throw new Error("non-optional Pi host peer: " + name);
  if (name in dependencies) throw new Error("Pi host peer bundled as dependency: " + name);
  if (existsSync(join(root, "node_modules", ...name.split("/")))) {
    throw new Error("Pi host peer present in installed closure: " + name);
  }
}
