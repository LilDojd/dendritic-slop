---
name: test-audit
description: "Invoke whenever writing, changing, reviewing, or sweeping tests in any codebase or language. Provides an authoring gate for new tests plus an audit workflow for finding and removing low-value, implementation-coupled, or duplicative tests and the test-only production seams they force into the code. Use it even when the user only says 'add a test', 'clean up the tests', 'our suite is slow/flaky/bloated', or 'review this PR's tests'."
---

# Test Audit

Three modes, one value bar.

- **Authoring mode** gates every new or changed test at write time.
- **Audit mode** runs focused sweeps for tests that re-assert source, duplicate
  stronger proof, couple behavior to implementation, or keep test-only
  production seams alive. Continue broad audits as separate, coherent
  follow-up changes; optimize for confidence, not deletion count.
- **Campaign mode** prunes one whole subsystem's test surface (every test file
  a module, package, service, or plugin owns). See [Campaign mode](#campaign-mode).

## Authoring gate

Before adding any test, answer four questions. A missing answer means do not
add it yet:

1. What observable behavior, invariant, or independent contract does it protect?
2. What credible regression makes it fail?
3. Why does existing coverage not already catch that failure? Each contract has
   one primary test owner at the strongest boundary; another layer needs its
   own distinct risk, such as a transport, serialization, or lifecycle failure
   the owner cannot reach. Prefer extending a table-driven/parameterized case or
   shared fixture over a near-duplicate test; consolidate duplicated setup in
   the same change.
4. Does it need a production seam (export, flag, wrapper, injection hook,
   visibility change) that no production caller needs? If yes, move the test
   to the real boundary instead.

Then check the test against every [junk pattern](#junk-patterns). A match fails
the gate unless the [retention bar](#retention-bar) names the contract it
independently guards. A test that would break under behavior-preserving
refactoring is asserting implementation, not behavior; rewrite it at the owning
boundary before landing it.

Bug regression tests must fail on the pre-fix code for the intended reason and
pass after the owner-boundary repair. A regression test that never demonstrably
failed proves the mock, not the fix. One regression at the owner boundary
covers the bug; do not replay the same scenario at every layer it crosses.

## Junk patterns

The shared checklist for all modes: the authoring gate rejects a new test that
matches one, and audits hunt for existing tests that do.

- assertion-free coverage probes;
- self-comparisons and identity copiers;
- copied fixtures, inventories, manifests, or export lists;
- exact source, import, or string greps;
- private predicate or call-shape tests duplicated at real boundaries;
- duplicate invocations of the same contract;
- per-implementation replays of shared helpers (each adapter/provider/backend
  re-testing the common code it delegates to);
- tests whose only purpose is preserving test-only exports, globals, or wrappers;
- dead production code whose only callers are tests;
- expected values produced by the helper or renderer under test;
- mocks that implement the asserted behavior, or one identical mock standing in
  for different APIs;
- fixtures that supply the receipt, admission, or callback ordering the owner
  should produce, or persistence asserted against a store the path never writes;
- capability tests that restate declared flags instead of exercising the
  delivery or acknowledgement the flag promises;
- negative controls that pass for an unrelated reason, such as a denial from a
  different guard or a rejection the production path never reaches;
- names or fixtures that promise more than the input exercises, such as a
  "clears the cache" test that never checks the cache was cleared.

## Value bar

Tests justify their maintenance cost by protecting behavior, a credible
regression, or an independently meaningful contract. In an audit, an existing
test that must change for behavior-preserving source reorganization is suspect,
not automatically deletable; the authoring gate still rejects new ones.

Before judging a candidate, read the complete test and its production owner,
the entry point, callers, callees, sibling implementations, overlapping tests,
CI configuration that decides when it runs, and relevant version-control
history. Read any repository contributor or agent guidance first (for example
`CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, or scoped equivalents). When the
test claims dependency-backed behavior, inspect the dependency's source or type
definitions directly rather than trusting the test's assumptions.

## Discovery

Keep discovery read-only and report evidence before editing. For broad scope,
split discovery into parallel lanes when available, for example:

- core libraries and packages;
- UI, apps, scripts, and tooling;
- a cross-cutting sweep for one junk pattern across the whole repository.

Outside campaign mode, prefer a few high-confidence candidates over a large
speculative inventory.

## Retention bar

Keep a test when it independently enforces a public API, extension/plugin
interface, wire protocol, configuration format, migration, storage format,
security boundary, platform behavior, default value, exact output bytes (such
as prompts, generated files, or snapshots consumed downstream),
cross-language generated code, packaging, release, or architecture contract.
Also keep:

- call ordering when order is observable behavior;
- regressions with a credible failure mode;
- source inspection when it is the cheapest independent guard: it fails when
  the contract changes (the user-facing key, byte, or path) and survives an
  identifier-only refactor;
- a retained test that fails on the baseline: treat it as a possible product
  bug, reproduce it, and repair the owner rather than deleting it.

Static or slow is not a deletion reason. A test that resembles implementation
may still be the independent contract; prove otherwise before removing it.

## Candidate evidence

Record every field below before editing. A missing field means the candidate is
not ready for deletion:

- exact test name and location;
- what failure it can actually detect;
- non-test callers of the covered production or support seam;
- stronger remaining owner-boundary proof, or why no proof is needed;
- relevant history and the reason the test or seam exists;
- production or test-support deletion unlocked;
- risk and the focused validation command.

## Edit shape

Choose one coherent owner-boundary batch. Delete obsolete test-only exports,
globals, wrappers, and dead production paths instead of preserving aliases.
Move retained regressions to their canonical owners. Consolidate repeated
package or dependency assertions into one generic contract.

Prefer net-negative production lines of code. Do not add replacement tests that
restate the same implementation, and do not convert uncertain candidates into
cleanup to increase deletion counts.

## Validation

Do not edit source or tests while the suite is running in the same checkout.
Use the repository's own test runner and CI conventions; if heavy suites are
routed to remote or sharded runners, follow that routing.

1. Run the smallest owning and sibling tests using the project's filtered test
   command (e.g. by path, file, or name pattern).
2. For removed source greps or plan/snapshot assertions, run the executable
   script, build step, or dry-run that owns the real contract.
3. Run targeted formatting and linting, then `git diff --check` (or the
   equivalent whitespace check for your VCS).
4. Run whatever changed-files or affected-targets gate the repository uses, then
   the full gate required by repository policy.
5. Inspect `git diff --numstat` (or equivalent); report production/tooling
   changes separately from tests and test support.
6. After final edits, get an independent review of the diff (a human reviewer
   or a separate review pass) before landing.

## Landing and continuation

Commit, push, open a pull request, or merge only when authorized. Follow the
repository's normal contribution flow. Land one coherent change at a time;
after it merges, refresh from the main branch and rerun read-only discovery for
the next high-confidence batch.

## Campaign mode

Use campaign mode only when asked to prune an entire subsystem. Differences
from a normal audit:

- Inventory every test file the subsystem owns before judging any of them, and
  map each to the contract(s) it claims to protect.
- Identify the primary owner test for each contract, then evaluate every other
  test against it; duplicates and weaker-layer replays are the main yield.
- A larger inventory is expected, but every deletion still needs full
  [candidate evidence](#candidate-evidence).
- Land the campaign as a sequence of coherent batches (for example, one per
  junk pattern or per owner boundary), not one sweeping change.
- Finish with a map of the subsystem's remaining tests and the contract each
  one owns.

## Handoff

Report:

- root cause and removed low-value categories;
- production owner simplifications;
- retained false positives and why they remain valuable;
- focused and full proof actually run;
- production versus test lines-of-code delta;
- pull request and merge state;
- named follow-ups.
