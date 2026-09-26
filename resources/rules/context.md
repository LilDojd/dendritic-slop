# Engineering principles

- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.

<!-- context7 -->
Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Always start with `resolve-library-id` using the library name and the user's question, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and the user's full question (not single words)
4. If you weren't satisfied with the answer, call `query-docs` again for the same library with `researchMode: true`. This retries with sandboxed agents that git-pull the actual source repos plus a live web search, then synthesizes a fresh answer. More costly than the default
5. Answer using the fetched docs
<!-- context7 -->

When devenv.nix doesn't exist and a command/tool is missing, create ad-hoc environment:

    $ devenv -O languages.rust.enable:bool true -O packages:pkgs "mypackage mypackage2" shell -- cli args

When the setup is becomes complex create `devenv.nix` and run commands within:

    $ devenv shell -- cli args

See https://devenv.sh/ad-hoc-developer-environments/

# Declarative self-management

Global agent and LLM tooling is managed by the `dendritic-slop` flake and its consuming host flake.

1. Change `dendritic-slop` for shared resources, or the consuming flake for host selection and secrets. Do not mutate runtime configuration or use `claude plugin install`, `claude mcp add`, `/config`, or `pi install`.
2. Pin and review external packages, skills, and extensions before enabling them.
3. Keep credentials and transient state outside the Nix store.
4. Format changed Nix files and run `nix flake check --no-eval-cache --no-build --all-systems`.

These rules do not restrict project-local agent or MCP configuration.

# Python tool selection

Respect each repository's existing Python package manager, formatter, linter, and type checker. Prefer project-pinned `uv run` tools, then declaratively packaged tools. Do not use `uvx`, install packages, or migrate project tooling without explicit user approval.
