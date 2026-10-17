---
name: context-audit
description: Audit project notes for stale claims. Use when a code change may have invalidated memory, before relying on a context note, or when asked to compare note path history with Git commits.
---

# Audit context freshness

## Procedure

1. Select the configured vault if accessible; otherwise inspect `<repo>\.context\`. List project notes with frontmatter fields `paths` and `last_verified_commit`.
2. For each note, run `scripts\check-freshness.ps1 -RepoPath <repo> -NotePath <note>`. The helper checks `git log <last_verified_commit>..HEAD -- <listed paths>` and prints `[FRESH]`, `[STALE]`, or an error.
3. Treat a missing/unreachable commit, absent path list, uncommitted change, or `unverified` marker as requiring manual inspection. The script detects committed history only; separately inspect the working tree with `git status --short` and compare relevant diff paths.
4. For a stale note, inspect only the changed paths that overlap its `paths`. Update affected statements after checking source. If the note is still accurate, verify that explicitly and advance its commit marker; otherwise correct it first.
5. Do not update notes as part of an audit unless asked or already authorized by the task. Report stale note paths, related commits/source paths, and the next evidence needed.

## Interpreting the helper

- Exit `0`: listed paths have no commits after the note's verification commit. This is a freshness signal, not proof that the prose was originally correct.
- Exit `2`: stale or unverified; inspect the note and source.
- Other non-zero exit: audit could not complete; report the Git or parsing error.

## Pass condition

Every checked note is labeled fresh, stale, or unverifiable with the evidence stated. Never treat a clean path-history result as a substitute for checking the current code when the note is vague or contradicted.
