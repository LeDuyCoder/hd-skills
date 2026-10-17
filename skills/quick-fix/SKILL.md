---
name: quick-fix
description: Make a small, local change fast while checking direction with the user. Use for one-spot fixes, tweaks, renames, copy or style changes, and small bugs with an obvious location.
---

# Quick fix with the user

Use this for small, well-bounded changes. Speed comes from doing the minimum, not from guessing: when the intended result is unclear, ask first.

## Procedure

1. Use `context-load` only for the affected area; skip broad exploration. Read the code at the spot the user points to and its immediate callers or tests.
2. Decide whether the request is clear. It is clear when you know the exact place to change and the result the user wants. It is unclear when any of these holds:
   - more than one place or behavior could be meant;
   - more than one reasonable fix exists and they behave differently for the user;
   - the fix changes a public interface, data, or behavior other code depends on.
3. If it is unclear, ask before editing. Keep it short: say what you found in one or two lines, then ask 1-3 numbered questions, each with concrete options (A/B) and your recommendation. Ask again if the answer still leaves the direction open.
4. When it is clear, make the smallest change that does the job. Keep the surrounding style. Do not refactor, rename, or "improve" nearby code that was not requested; mention such ideas in one line instead.
5. Run the fastest relevant check from the project overview: the affected test, lint for the file, or a build. If no check applies, say how the change can be checked by hand.
6. If the check fails because of the change, fix it. If it fails for an unrelated reason, report it and do not chase it.
7. Report briefly: what changed (file and line), how it was checked, and any follow-up the user may want.
8. Switch to `deep-task` and tell the user when the change turns out to touch many files, needs design decisions, or keeps revealing new problems. Switch to `systematic-debugging` when the cause of a bug is not visible at the reported spot.
9. Use `context-update` only when the fix revealed a durable gotcha or changed a documented command or behavior; routine fixes need no note.

## Pass condition

The user's intended result was clear before editing, the change is limited to what was asked, a relevant check was run or a manual check was described, and the report states what changed.
