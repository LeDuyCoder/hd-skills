---
name: pull-request
description: Prepare a clear pull request summary from a verified branch diff, including behavior, rationale, and checks.
---

# Prepare a pull request

1. Start with `context-load` and inspect repository guidance, branch, upstream, and complete diff.
2. Confirm the branch contains only intended changes. Read `overview.md` and identify relevant verification commands from the project itself.
3. Summarize the user-visible behavior and reason for the change. Organize a draft into summary, notable implementation details, and checks.
4. Include exact test results and disclose unrun checks or known limitations. Do not say CI passed unless current CI evidence supports it.
5. Review the draft for secrets, local paths, unrelated details, and unsupported claims.
6. Create or publish the pull request only when the user asked for that action and a suitable Git hosting tool is available. Otherwise provide the ready-to-paste draft.
7. Call `context-update` if the change establishes a lasting project decision or release convention.

## Pass condition

The draft is accurate to the diff, gives reviewers useful verification evidence, and external publication stays within the user's request.
