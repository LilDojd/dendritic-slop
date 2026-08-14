---
name: verification-before-completion
description: Verify work with fresh commands and inspected output before claiming success. Use before reporting that code, configuration, tests, builds, deployments, or fixes are complete.
---

# Verification before completion

Evidence must precede completion claims.

1. Identify the command or observation that directly proves each important claim.
2. Run it after the final change, using the same environment and scope the user requested.
3. Read the exit status and relevant output; do not infer success from partial logs or an earlier run.
4. Inspect the final diff or generated result for unintended changes.
5. Report exactly what was verified and disclose anything skipped, unavailable, flaky, or still failing.

Never say that tests pass, a build succeeds, a deployment completed, or a bug is fixed without current evidence. If verification fails, continue the task or report the failure plainly.
