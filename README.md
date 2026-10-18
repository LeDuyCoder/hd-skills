<div align="center">

# 🧠 hd-skill

**Bộ skill cho AI coding agent: làm task có quy trình, nhớ ngữ cảnh dự án trong Obsidian**

Claude Code · Codex · Antigravity · Cursor · Copilot · Gemini CLI · và AI bạn tự thêm

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Obsidian](https://img.shields.io/badge/Vault-Obsidian-7C3AED?logo=obsidian&logoColor=white)](https://obsidian.md/)
[![Repo](https://img.shields.io/badge/GitHub-LeDuyCoder%2Fhd--skills-181717?logo=github&logoColor=white)](https://github.com/LeDuyCoder/hd-skills)

</div>

---

## ✨ Bộ skill làm được gì

| | Khả năng |
|---|---|
| 🧩 **Làm task có quy trình** | `/hd task`: hỏi đến khi hiểu rõ → lập kế hoạch để bạn duyệt → làm từng bước kèm test → tìm nguyên nhân gốc khi lỗi → lặp đến khi đạt mọi tiêu chí. `/hd quick`: sửa nhanh một chỗ, hỏi lại khi chưa rõ hướng. |
| 🧠 **Nhớ ngữ cảnh dự án** | Agent ghi kiến trúc, quyết định và lưu ý của từng dự án vào vault Obsidian. Lần sau nó đọc lại đúng phần cần, không phải tìm hiểu lại từ đầu. Dùng được trên nhiều máy. |
| ✅ **Code chắc tay hơn** | Lập kế hoạch, TDD, debug có hệ thống, kiểm chứng trước khi báo xong, review code, refactor, rà soát bảo mật. |
| 🔀 **Git & CI** | Commit an toàn, chuẩn bị Pull Request, sửa CI lỗi, nâng cấp dependency. |
| 🤖 **Một bộ, nhiều AI** | Cùng một bộ skill cho mọi agent bạn chọn. Cài cho cả máy hoặc riêng từng dự án (commit lên Git cho cả team). |

---

## ⚡ Cài đặt

> **Cần có:** Windows 10/11, [Git for Windows](https://git-scm.com/download/win), PowerShell 5.1+ và ít nhất một AI agent. Không cần quyền admin.

### 1️⃣ Cài skill

Mở PowerShell **trong thư mục dự án** rồi chạy:

```powershell
irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/get.ps1 | iex
```

Lệnh hỏi hai câu:

```text
hd-skill: where should the skills be installed?
  [1] Global  - every project on this machine
  [2] Project - only this folder
Choose 1 or 2 [1]: 1

hd-skill: which AI agents should get the skills?
  [1] [x] OpenAI Codex         codex        detected
  [2] [ ] Google Antigravity   antigravity
  [3] [x] Claude Code          claude       detected
  [4] [ ] Cursor               cursor
  [5] [ ] GitHub Copilot       copilot
  [6] [ ] Gemini CLI           gemini
Numbers separated by commas (e.g. 1,3), a = all, Enter = keep [x]: 1,3
```

- **Global** cài một lần cho mọi dự án. **Project** chỉ cài cho dự án hiện tại.
- Chọn AI bằng số, cách nhau bởi dấu phẩy. Gõ `a` để chọn tất cả, Enter để giữ các mục `[x]`.
- Chạy lại đúng lệnh này khi muốn **cập nhật** hoặc **đổi AI**.

### 2️⃣ Kết nối Obsidian *(tuỳ chọn)*

```powershell
irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/obsidian.ps1 | iex
```

Lệnh liệt kê các vault Obsidian trên máy, hoặc tạo vault mới. Sau đó nó chuẩn bị vault và lưu vault làm nơi chứa ghi chú dự án. Vault mới tạo cần mở trong Obsidian một lần: **Open folder as vault**.

> Không dùng Obsidian vẫn được: ghi chú sẽ lưu trong thư mục `.context\` của dự án.

### 🎉 Bắt đầu

Khởi động lại agent, mở dự án và gõ:

```text
/hd                hiện menu lệnh
/hd init           tạo ghi chú đầu tiên cho dự án
/hd task <mô tả>   làm một task lớn
```

> Trong Codex, dùng `$hd` thay cho `/hd`.

---

## 🧰 Lệnh `/hd`

| Lệnh | Việc làm | | Lệnh | Việc làm |
|---|---|---|---|---|
| `task` | Task lớn, đầy đủ quy trình | | `quick` | Sửa nhanh một chỗ |
| `plan` | Lập kế hoạch | | `debug` | Tìm nguyên nhân gốc của lỗi |
| `tdd` | Viết test trước, code sau | | `verify` | Kiểm chứng trước khi báo xong |
| `review` | Rà soát thay đổi | | `refactor` | Tái cấu trúc an toàn |
| `security` | Rà soát bảo mật | | `commit` | Commit và đồng bộ Git |
| `pr` | Chuẩn bị Pull Request | | `ci` | Sửa CI lỗi |
| `deps` | Nâng cấp dependency | | `shell` | Làm việc an toàn với PowerShell |
| `init` | Tạo ghi chú dự án | | `load` | Đọc lại ngữ cảnh dự án |
| `save` | Ghi lại thay đổi quan trọng | | `audit` | Kiểm tra ghi chú còn đúng không |
| `handoff` | Bàn giao phiên làm việc | | `stack` | Tạo skill riêng cho stack của dự án |
| `improve` | Cải tiến một skill | | `all` | Xem đủ mọi lệnh |

Không cần gõ `/hd`: agent vẫn tự chọn quy trình phù hợp với độ lớn của việc.

---

## 🤖 AI được hỗ trợ

**Claude Code, OpenAI Codex, Google Antigravity, Cursor, GitHub Copilot, Gemini CLI.**

Muốn thêm AI khác, tạo file `%USERPROFILE%\.hd-skill\agents.custom.json` theo mẫu dưới đây. AI đó sẽ xuất hiện trong menu ở bước 1.

```json
{
  "agents": [
    {
      "id": "myai",
      "name": "My AI",
      "detect": { "paths": [".myai"], "commands": [] },
      "global": { "skillsPath": ".myai\\skills", "rulesPath": ".myai\\RULES.md" },
      "project": { "skillsPath": ".myai\\skills", "rulesPath": "AGENTS.md" }
    }
  ]
}
```

`global` là đường dẫn tính từ `%USERPROFILE%`, `project` là đường dẫn tính từ gốc dự án. Danh sách AI có sẵn nằm trong [agents.json](agents.json).

---

## 🗑️ Gỡ cài

```powershell
# Gỡ bản cài cho cả máy
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/get.ps1))) -Scope Global -Uninstall

# Gỡ khỏi dự án hiện tại
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/get.ps1))) -Scope Project -Uninstall
```

Khi gỡ, hd-skill chỉ xoá những gì nó đã tạo. File của bạn và ghi chú trong vault được giữ nguyên.
