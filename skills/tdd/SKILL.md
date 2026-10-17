---
name: tdd
description: Develop behavior changes through a failing test, a minimal implementation, and a passing verification cycle.
---

# Test-driven change

1. Begin with `context-load`, which resolves the project's context location before note access.
2. Read the overview and inspect the existing test layout, fixtures, and assertions. Derive the test command from the overview or repository scripts; do not hard-code a test runner.
3. Write one focused test for the requested behavior and run it. Confirm it fails for the expected reason rather than because the harness is broken.
4. Implement the smallest change that makes the test pass. Keep public behavior and error cases explicit.
5. Run the focused test, then relevant neighboring tests and project checks listed in the overview. Report any check that could not run.
6. Refactor only while the tests remain green. Do not modify unrelated behavior to satisfy an incidental test detail.
7. Call `context-update` when the change alters durable project behavior, test conventions, or a recurring gotcha.

## Pass condition

The new test demonstrates the behavior, passed checks are named accurately, and the final diff contains only the requested change and supporting tests.
