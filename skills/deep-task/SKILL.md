---
name: deep-task
description: Run a large or open-ended task as a loop of clarify, plan, implement, test, and fix until it is complete. Use for new features, multi-file changes, unclear requirements, or work that needs design decisions.
---

# Large task loop

Use this for work that is too big or too unclear to finish in one small edit. The loop keeps going until every acceptance condition is met, and goes back to clarifying whenever a new problem changes what must be built.

## Phase 1 - Clarify until the problem is understood

1. Start with `context-load`. Read the overview, architecture, and gotchas notes for the affected area, then inspect the related code so questions are grounded in what exists.
2. Restate the request in your own words: the goal, who or what uses the result, and what "done" looks like.
3. Ask the user questions in rounds. Each round asks at most 3-5 focused questions, numbered, with your recommended answer or the likely options for each, so the user can reply briefly. Cover, as relevant:
   - expected behavior and edge cases, including error and empty states;
   - scope: what is explicitly out of scope;
   - constraints: compatibility, data, performance, security, existing conventions;
   - acceptance: how the user will check that it works.
4. After each answer, update the restated understanding and ask the next round. Keep asking until there are no open questions that would change the design. Do not guess on anything that changes behavior, data, or public interfaces.
5. When the work has more than one reasonable approach, present 2-3 options with trade-offs and a recommendation, and let the user choose.
6. End the phase with a short summary: goal, chosen approach, scope, acceptance conditions. Get the user's confirmation before planning. If the user says to proceed without more questions, record the remaining assumptions explicitly and continue.

## Phase 2 - Plan

7. Follow `planning` for the confirmed understanding: ordered steps, affected files, a verification check per step, and early risks.
8. Show the plan and wait for the user's go-ahead before changing code, unless the user already said to implement without review.

## Phase 3 - Build, test, fix (loop)

9. Implement one plan step at a time. Prefer `tdd` when the project has a test setup: write or extend a failing test, make it pass, then clean up.
10. After each step, run the project's verification commands from the overview (tests, lint, type-check, build). Report the real results.
11. When something fails, follow `systematic-debugging`: reproduce, find the root cause, fix it, rerun the checks. Do not stack guesses or silence failing tests.
12. When the failure or new information reveals a new problem - a missing requirement, a design flaw, a conflict with existing behavior, or a choice the user has not made - stop building and return to Phase 1 for that problem only: explain what was found, ask the questions it raises, agree on the direction, and update the plan. Then resume the loop.
13. Keep a short progress list (done, in progress, next, open questions) and show it when a step finishes or the plan changes.
14. Repeat steps 9-13 until every plan step is done and every acceptance condition has evidence.

## Phase 4 - Finish

15. Run `verification-before-done`: map each acceptance condition to the command, test, or observation that proves it. Name any check that was not run.
16. Offer `code-review` for the full change. Commit or open a pull request only when the user asks (`git-workflow`, `pull-request`).
17. Use `context-update` to record durable decisions, architecture changes, new commands, and verified gotchas. Use `session-handoff` instead if the work stops before completion.

## Pass condition

The user confirmed the understanding and plan, every acceptance condition has recorded evidence, all failures found during the loop were fixed at their cause or reported as open, and context notes reflect durable changes.
