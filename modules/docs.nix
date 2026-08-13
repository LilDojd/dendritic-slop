{
  config,
  lib,
  self,
  ...
}:
let
  inherit (config.dendriticSlopInternal) resources;
  revision = self.rev or "main";
  repository = "https://github.com/LilDojd/dendritic-slop/blob/${revision}";

  renderKind = kind: catalog: ''
    ## ${if kind == "skills" then "Skills" else "Extensions"}

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        resource = catalog.${name};
      in
      ''
        ### ${resource.title}

        ${resource.description}

        - Option: `dendriticSlop.${kind}.${name}.enable`
        - Source: [`${kind}/${name}`](${repository}/resources/${kind}/${name})
        ${lib.optionalString (
          resource ? homepage
        ) "- Upstream: [${resource.homepage}](${resource.homepage})"}
        ${lib.optionalString (
          resource.requiresTargets != [ ]
        ) "- Requires target: `${lib.concatStringsSep "`, `" resource.requiresTargets}`"}
      ''
    ) (builtins.attrNames catalog)}
  '';

  catalog = ''
    # Resource catalog

    Resources are discovered from `resources/`. They follow `dendriticSlop.autoEnable` and can be overridden individually.

    ${renderKind "skills" resources.skills}
    ${renderKind "extensions" resources.extensions}
  '';
in
{
  perSystem =
    { pkgs, ... }:
    let
      catalogMarkdown = pkgs.writeText "catalog.md" catalog;
      docs = pkgs.stdenvNoCC.mkDerivation {
        pname = "dendritic-slop-docs";
        version = self.shortRev or "dirty";
        src = ../docs;
        nativeBuildInputs = [ pkgs.mdbook ];
        patchPhase = ''
          runHook prePatch
          cp ${../README.md} src/index.md
          cp ${catalogMarkdown} src/catalog.md
          runHook postPatch
        '';
        buildPhase = ''
          runHook preBuild
          mdbook build
          runHook postBuild
        '';
        installPhase = ''
          cp -r book "$out"
        '';
      };
    in
    {
      checks.docs = docs;
      packages.docs = docs;
    };
}
