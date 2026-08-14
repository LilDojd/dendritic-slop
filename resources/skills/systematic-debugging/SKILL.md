---
name: systematic-debugging
description: Diagnose bugs, failing tests, and unexpected behavior by gathering evidence and isolating the cause before changing code. Use whenever a failure's root cause is not already demonstrated.
---

# Systematic debugging

Fix causes, not symptoms.

1. Reproduce the failure with the smallest reliable command or input.
2. Read the complete error and identify the first meaningful failure, not only the final summary.
3. Inspect the failing boundary: inputs, outputs, configuration, versions, and recent relevant changes.
4. Form one falsifiable hypothesis that explains the evidence.
5. Test that hypothesis with the smallest observation or change. Change one variable at a time.
6. Once the cause is demonstrated, implement the smallest durable fix.
7. Re-run the reproducer and nearby regression checks. Inspect their exit status and output.

Do not stack speculative fixes, weaken tests, or claim a root cause without evidence. If repeated hypotheses fail, stop and reassess assumptions or ask for missing information.
