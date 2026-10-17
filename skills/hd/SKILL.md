---
name: hd
description: Command router for the hd-skill pack. Use only when the user types /hd or $hd, optionally followed by a subcommand such as task, quick, debug, review, or save, or asks for the hd command menu.
---

# hd command router

Antigravity invokes this skill as `/hd`; Codex invokes it as `$hd`. Everything after `hd` is the subcommand and its task text, for example `/hd debug login test fails` or `$hd review`.

## Procedure

1. Split the input into the first word (the subcommand) and the remaining text (the task).
2. With no subcommand, or with `help` or `?`, print the **short menu** below exactly as written, inside a code block, and stop. With `all`, `more`, or `menu`, print the **full menu** the same way and stop. In Codex, write `$hd` wherever the menu says `/hd`. Do not add the routing table, extra commentary, or start any work.
3. When the first word matches a command or alias in the routing table, open the mapped skill's `SKILL.md` from the same skills directory as this file (`../<skill>/SKILL.md`) and follow it completely, using the remaining text as the task. If the task text is empty and the skill needs one, ask a single question for it.
4. When the first word matches nothing, treat the whole input as the task. If it is a piece of work to build or change, use `quick-fix` for a small change at a known spot and `deep-task` for anything larger or unclear. Otherwise pick the one skill whose purpose fits best. Name the choice in one line (for example "Using `quick-fix`."), then follow it. If two choices fit equally, ask which one to use.
5. Keep the mapped skill's own authorization limits and pass conditions. This router adds no permissions and skips no steps; for example, `commit` and `pr` still need the user's go-ahead to push or open a pull request.

## Short menu

```text
hd · lệnh hay dùng                               /hd all → xem đủ

 LÀM VIỆC
   /hd task  <mô tả>   Task lớn: hỏi rõ → kế hoạch → làm → test → sửa, lặp đến xong
   /hd quick <mô tả>   Sửa nhanh một chỗ, chưa rõ hướng sẽ hỏi lại
   /hd debug <lỗi>     Tìm nguyên nhân gốc của lỗi

 TRƯỚC KHI GIAO
   /hd review          Rà soát thay đổi hiện tại
   /hd commit          Commit và đồng bộ Git an toàn

 GHI CHÚ DỰ ÁN
   /hd init            Tạo ghi chú dự án lần đầu
   /hd save            Lưu thay đổi quan trọng vào ghi chú

 Mẹo: /hd <mô tả> không kèm lệnh → tự chọn task hoặc quick
```

## Full menu

```text
hd · tất cả lệnh                         (tên trong ngoặc là tên gọi tắt)

 LÀM VIỆC
   task      (new, big)     Task lớn: hỏi rõ → kế hoạch → làm → test → sửa, lặp đến xong
   quick     (q, small)     Sửa nhanh một chỗ, chưa rõ hướng sẽ hỏi lại
   debug     (fix)          Tìm nguyên nhân gốc của lỗi
   plan                     Chỉ lập kế hoạch có tiêu chí kiểm chứng
   tdd       (test)         Viết test trước rồi mới viết code
   refactor                 Sắp xếp lại code, giữ nguyên hành vi

 KIỂM TRA & GIAO
   verify    (done)         Kiểm chứng xong việc thật trước khi báo
   review    (cr)           Rà soát thay đổi hiện tại
   security  (sec)          Tìm lỗ hổng bảo mật
   commit    (git)          Tạo nhánh, commit, đồng bộ Git an toàn
   pr                       Chuẩn bị pull request
   ci                       Tìm và sửa lỗi CI

 GHI CHÚ DỰ ÁN
   init      (bootstrap)    Tạo ghi chú dự án lần đầu
   load      (ctx)          Đọc ghi chú trước khi làm
   save      (update)       Lưu thay đổi quan trọng vào ghi chú
   audit     (fresh)        Tìm ghi chú đã cũ so với code
   handoff   (pause)        Viết bàn giao khi dừng giữa chừng

 KHÁC
   deps      (upgrade)      Nâng cấp thư viện an toàn
   shell     (ps)           Chạy lệnh PowerShell/Windows an toàn
   stack                    Sinh skill riêng theo công nghệ dự án
   improve                  Cải tiến một skill của hd-skill
```

## Routing table

Internal reference for steps 3 and 4; never print it.

| Command | Aliases | Skill |
|---|---|---|
| `task` | `new`, `big` | `deep-task` |
| `quick` | `q`, `small` | `quick-fix` |
| `debug` | `fix` | `systematic-debugging` |
| `plan` | | `planning` |
| `tdd` | `test` | `tdd` |
| `refactor` | | `refactoring` |
| `verify` | `done` | `verification-before-done` |
| `review` | `cr` | `code-review` |
| `security` | `sec` | `security-review` |
| `commit` | `git` | `git-workflow` |
| `pr` | | `pull-request` |
| `ci` | | `fix-ci` |
| `init` | `bootstrap` | `context-bootstrap` |
| `load` | `ctx` | `context-load` |
| `save` | `update` | `context-update` |
| `audit` | `fresh` | `context-audit` |
| `handoff` | `pause` | `session-handoff` |
| `deps` | `upgrade` | `dependency-upgrade` |
| `shell` | `ps` | `windows-shell` |
| `stack` | | `stack-skill-generator` |
| `improve` | | `skill-improve` |

## Pass condition

The user sees the requested menu exactly as written, or the mapped skill runs to its own pass condition with the given task text.
