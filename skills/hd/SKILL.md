---
name: hd
description: Command router for the hd-skill pack. Use only when the user types /hd or $hd, optionally followed by a subcommand such as plan, debug, review, or save, or asks for the hd command menu.
---

# hd command router

Antigravity invokes this skill as `/hd`; Codex invokes it as `$hd`. Everything after `hd` is the subcommand and its task text, for example `/hd debug login test fails` or `$hd review`.

## Procedure

1. Split the input into the first word (the subcommand) and the remaining text (the task).
2. With no subcommand, or with `help` or `?`, print the command table below in the user's language and stop. Do not start any work.
3. When the first word matches a command or alias in the table, open the mapped skill's `SKILL.md` from the same skills directory as this file (`../<skill>/SKILL.md`) and follow it completely, using the remaining text as the task. If the task text is empty and the skill needs one, ask a single question for it.
4. When the first word matches nothing, treat the whole input as the task. If it is a piece of work to build or change, use `quick-fix` for a small change at a known spot and `deep-task` for anything larger or unclear. Otherwise pick the one skill whose purpose fits best. Name the choice in one line (for example "Using `quick-fix`."), then follow it. If two choices fit equally, ask which one to use.
5. Keep the mapped skill's own authorization limits and pass conditions. This router adds no permissions and skips no steps; for example, `commit` and `pr` still need the user's go-ahead to push or open a pull request.

## Commands

| Command | Aliases | Skill | Purpose |
|---|---|---|---|
| `task` | `new`, `big` | `deep-task` | Large task: clarify with questions, plan, build, test, fix, loop until done |
| `quick` | `q`, `small` | `quick-fix` | Small fix at a known spot; asks when the direction is unclear |
| `init` | `bootstrap` | `context-bootstrap` | Create the first context notes for this project |
| `load` | `ctx` | `context-load` | Load project context before working |
| `save` | `update` | `context-update` | Record durable changes in the context notes |
| `audit` | `fresh` | `context-audit` | Check context notes for stale claims |
| `handoff` | `pause` | `session-handoff` | Write a handoff before pausing or transferring work |
| `plan` | | `planning` | Turn a request into a verifiable plan |
| `tdd` | `test` | `tdd` | Build a change test-first |
| `debug` | `fix` | `systematic-debugging` | Find the root cause of a bug |
| `verify` | `done` | `verification-before-done` | Prove the work is complete before reporting |
| `review` | `cr` | `code-review` | Review the current changes |
| `refactor` | | `refactoring` | Restructure code without changing behavior |
| `security` | `sec` | `security-review` | Look for security problems |
| `git` | `commit` | `git-workflow` | Branch, commit, and sync safely |
| `pr` | | `pull-request` | Prepare a pull request |
| `ci` | | `fix-ci` | Diagnose and fix a failing CI run |
| `deps` | `upgrade` | `dependency-upgrade` | Upgrade dependencies safely |
| `shell` | `ps` | `windows-shell` | Run PowerShell and Windows commands safely |
| `stack` | | `stack-skill-generator` | Generate project-specific stack skills |
| `improve` | | `skill-improve` | Improve an hd-skill skill from experience |

## Pass condition

The user either sees the command table, or the mapped skill runs to its own pass condition with the given task text.
