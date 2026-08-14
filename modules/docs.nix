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
        - Default: `disabled` unless selected by a profile
        - Definition: [`${kind}/${name}`](${repository}/resources/${kind}/${name})
        ${lib.optionalString (
          resource ? homepage
        ) "- Homepage: [${resource.homepage}](${resource.homepage})"}
        ${lib.optionalString (
          resource.requiresTargets != [ ]
        ) "- Required target: `${lib.concatStringsSep "`, `" resource.requiresTargets}`"}
      ''
    ) (builtins.attrNames catalog)}
  '';

  renderHerdrPlugins = ''
    ## Herdr plugins

    Herdr plugins execute as the user, are disabled by default, and require `dendriticSlop.targets.herdr.enable = true`.

    ${lib.concatMapStringsSep "\n" (
      name:
      let
        resource = resources.herdrPlugins.${name};
      in
      ''
        ### ${resource.title}

        ${resource.description}

        - Option: `dendriticSlop.herdr.plugins.${name}.enable`
        - Default: `disabled`
        - Required target: `herdr`
        - Plugin ID: `${resource.id}`
        - Version: `${resource.version}`
        - Actions: `${lib.concatStringsSep "`; `" resource.actions}`
        - Definition: [`herdr-plugins/${name}`](${repository}/resources/herdr-plugins/${name})
        ${lib.optionalString (
          resource ? homepage
        ) "- Homepage: [${resource.homepage}](${resource.homepage})"}
      ''
    ) (builtins.attrNames resources.herdrPlugins)}
  '';

  catalog = ''
    # Resource catalog

    Each resource can be enabled independently or through an explicit profile. Herdr plugins are always opt-in unless a selected profile names them.

    ${renderKind "skills" resources.skills}
    ${renderKind "extensions" resources.extensions}
    ${renderHerdrPlugins}
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
