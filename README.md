<div align="center">

# 🧠 hd-skill

**Một bộ skill cho mọi AI coding agent · bộ nhớ dự án nằm trong Obsidian**

Claude Code · Codex · Antigravity · Cursor · Copilot · Gemini CLI · và AI bạn tự thêm

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Claude Code](https://img.shields.io/badge/Agent-Claude%20Code-D97757)](https://claude.com/claude-code)
[![Codex](https://img.shields.io/badge/Agent-Codex-111111)](https://github.com/openai/codex)
[![Antigravity](https://img.shields.io/badge/Agent-Antigravity-4285F4)](https://antigravity.google/)
[![Obsidian](https://img.shields.io/badge/Vault-Obsidian-7C3AED?logo=obsidian&logoColor=white)](https://obsidian.md/)

</div>

---

## ⚡ Cài đặt: 2 lệnh

> **Cần có:** Windows 10/11, [Git for Windows](https://git-scm.com/download/win), PowerShell 5.1+ (khuyên dùng PowerShell 7) và ít nhất một AI agent đã cài. Không cần quyền admin. hd-skill không tự cài phần mềm nào.

### 1️⃣ Cài skill

Mở PowerShell **trong thư mục dự án** rồi chạy:

```powershell
irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1 | iex
```

Lệnh hỏi bạn hai câu:

```text
hd-skill: where should the skills be installed?
  [1] Global  - every project on this machine (agent user folders)
  [2] Project - only this folder: D:\code\my-app
Choose 1 or 2 [1]: 1

hd-skill: which AI agents should get the skills?
  [1] [x] OpenAI Codex         codex        detected
  [2] [ ] Google Antigravity   antigravity
  [3] [x] Claude Code          claude       detected
  [4] [ ] Cursor               cursor
  [5] [ ] GitHub Copilot       copilot
  [6] [ ] Gemini CLI           gemini
Numbers separated by commas (e.g. 1,3), a = all, Enter = keep [x]: 1,3,4
```

| Câu hỏi | Chọn gì |
|---|---|
| **Nơi cài** | `1` **Global**: một lần cho mọi dự án trên máy. `2` **Project**: chỉ dự án hiện tại, có thể commit lên Git để cả team dùng chung. |
| **AI agent** | Gõ số, cách nhau bằng dấu phẩy. `a` = tất cả. **Enter** = giữ các mục đang đánh `[x]` (lựa chọn lần trước, hoặc agent tìm thấy trên máy). |

Lựa chọn được lưu lại, nên lần sau chỉ cần chạy lại **đúng lệnh trên** để cập nhật. Nếu bỏ chọn một agent, skill và rule của agent đó sẽ được gỡ.

<details>
<summary><b>Chạy không cần hỏi (script / CI)</b></summary>

```powershell
# Truyền tham số: -Scope Global|Project  -Agents <id,...>|all|detected  -DryRun  -Uninstall  -VaultPath  -WithMcp  -NonInteractive
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1))) -Scope Global -Agents claude,codex

# Chỉ xem trước kế hoạch, không ghi gì
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1))) -Scope Project -Agents claude -DryRun

# Hoặc dùng biến môi trường
$env:HD_SKILL_SCOPE = 'Project'; $env:HD_SKILL_AGENTS = 'claude,cursor'
irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1 | iex
```

</details>

### 2️⃣ Kết nối Obsidian *(tuỳ chọn)*

```powershell
irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/obsidian.ps1 | iex
```

```text
hd-skill: which Obsidian vault should hold the project notes?
  [1] DevBrain             D:\Notes\DevBrain
  [2] Personal             D:\Notes\Personal
  [n] Create a new vault folder
  [p] Type the path of an existing folder
Choose [1]:
```

Lệnh này sẽ:

- ✅ đọc danh sách vault Obsidian trên máy, hoặc tạo thư mục vault mới;
- ✅ tạo `00-INDEX.md` và `projects\` nếu vault còn trống (không ghi đè note có sẵn);
- ✅ lưu vault vào `%USERPROFILE%\.hd-skill\config.json` và cập nhật lại bản cài.

Vault mới tạo cần được mở trong Obsidian một lần: **Open folder as vault → chọn thư mục đó**.

> **Không dùng Obsidian?** Bỏ qua bước này. Skill vẫn chạy và lưu note vào `.context\` trong repo (đã nằm trong `.gitignore`).

<details>
<summary><b>Tuỳ chọn của lệnh kết nối</b></summary>

```powershell
# Chỉ định vault, không hỏi
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/obsidian.ps1))) -VaultPath 'D:\Tài liệu\DevBrain'

# Bật thêm filesystem MCP cho vault (cần Node.js LTS; mặc định tắt)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/obsidian.ps1))) -WithMcp

# Từ checkout có sẵn
& "$env:USERPROFILE\.hd-skill\repo\obsidian.ps1" -VaultPath 'D:\Notes\DevBrain' -DryRun
```

</details>

### 🎉 Dùng thử

Khởi động lại agent, mở dự án và gõ:

```text
/hd              hiện menu lệnh            (Codex: $hd)
/hd init         tạo note đầu tiên cho dự án
/hd task <...>   làm task lớn: hỏi rõ → kế hoạch → làm → test → lặp đến xong
```

---

## 🤖 Agent được hỗ trợ

| Agent | `id` | Skill (Global) | Rule (Global) | Skill + rule (Project) | Gọi lệnh |
|---|---|---|---|---|---|
| Claude Code | `claude` | `~\.claude\skills` | `~\.claude\CLAUDE.md` | `.claude\skills` + `CLAUDE.md` | `/hd` |
| OpenAI Codex | `codex` | `~\.agents\skills` | `~\.codex\AGENTS.md` | `.agents\skills` + `AGENTS.md` | `$hd` |
| Google Antigravity | `antigravity` | `~\.gemini\config\skills` | `~\.gemini\config\GEMINI.md` | `.agents\skills` + `AGENTS.md` | `/hd` |
| Cursor | `cursor` | `~\.agents\skills` | *(trong Cursor Settings → Rules)* | `.agents\skills` + `AGENTS.md` | `/hd` |
| GitHub Copilot | `copilot` | `~\.agents\skills` | `~\.copilot\copilot-instructions.md` | `.agents\skills` + `AGENTS.md` | `/hd` |
| Gemini CLI | `gemini` | `~\.agents\skills` | `~\.gemini\GEMINI.md` | `.agents\skills` + `AGENTS.md` | `/hd` |

`~` là `%USERPROFILE%`. Codex, Cursor, Copilot và Gemini CLI cùng đọc `~\.agents\skills`, nên thư mục này chỉ được cài **một lần** dù bạn chọn nhiều agent. Bảng trên được định nghĩa trong [agents.json](agents.json).

### ➕ Thêm AI của riêng bạn

Tạo file `%USERPROFILE%\.hd-skill\agents.custom.json`. Agent mới sẽ xuất hiện trong menu ở bước 1. Nếu trùng `id` với agent có sẵn, mục của bạn sẽ thay thế mục gốc, nên cũng dùng được để sửa đường dẫn.

```json
{
  "agents": [
    {
      "id": "windsurf",
      "name": "Windsurf",
      "detect": { "paths": [".codeium\\windsurf"], "commands": [] },
      "global": { "skillsPath": ".codeium\\windsurf\\skills", "rulesPath": ".codeium\\windsurf\\memories\\global_rules.md", "rulesSource": "rules\\AGENTS.md" },
      "project": { "skillsPath": ".windsurf\\skills", "rulesPath": "AGENTS.md" }
    }
  ]
}
```

| Trường | Ý nghĩa |
|---|---|
| `id` | Chữ thường, số, `-` hoặc `_`; dùng trong `-Agents` |
| `detect.paths` / `detect.commands` | Thư mục (tính từ `%USERPROFILE%`) hoặc lệnh trên PATH dùng để đánh dấu *detected* |
| `global.skillsPath` | **Bắt buộc.** Nơi đặt skill khi cài Global |
| `global.rulesPath` | File rule toàn cục; `null` nếu agent không có |
| `project.skillsPath` / `project.rulesPath` | Đích khi cài Project, tính từ gốc dự án |

Đường dẫn ở ví dụ Windsurf chỉ để minh hoạ; hãy kiểm tra tài liệu của agent bạn dùng.

---

## 🧰 Lệnh `/hd` và danh mục skill

`hd` là bộ định tuyến lệnh: gõ `/hd <lệnh>` và nó chuyển việc sang đúng skill. `/hd` hiện menu rút gọn, `/hd all` hiện đủ mọi lệnh. Không gõ `/hd` thì agent vẫn tự chọn quy trình phù hợp.

| Lệnh | Skill | | Lệnh | Skill |
|---|---|---|---|---|
| `task` | `deep-task` | | `quick` | `quick-fix` |
| `init` | `context-bootstrap` | | `review` | `code-review` |
| `load` | `context-load` | | `refactor` | `refactoring` |
| `save` | `context-update` | | `security` | `security-review` |
| `audit` | `context-audit` | | `commit` | `git-workflow` |
| `handoff` | `session-handoff` | | `pr` | `pull-request` |
| `plan` | `planning` | | `ci` | `fix-ci` |
| `tdd` | `tdd` | | `deps` | `dependency-upgrade` |
| `debug` | `systematic-debugging` | | `shell` | `windows-shell` |
| `verify` | `verification-before-done` | | `stack` | `stack-skill-generator` |
| | | | `improve` | `skill-improve` |

- **`/hd task <mô tả>`** dành cho việc lớn hoặc chưa rõ: hỏi từng đợt đến khi hiểu, lập kế hoạch để bạn duyệt, làm từng bước kèm test, lặp đến khi đạt mọi tiêu chí rồi ghi vào vault.
- **`/hd quick <mô tả>`** dành cho sửa một chỗ: sửa tối thiểu, chạy kiểm tra nhanh. Nếu việc phình to, nó tự chuyển sang `task`.

Bí danh và mô tả từng lệnh nằm trong [skills/hd/SKILL.md](skills/hd/SKILL.md). Mỗi skill vẫn gọi trực tiếp được, ví dụ `/tdd` (Codex: `$tdd`).

## 🧠 Bộ nhớ dự án

Trong một dự án mới, chạy `/hd init` để nhận diện stack và tạo note khởi đầu trong vault. Các phiên sau, agent tự gọi `context-load` để đọc `00-INDEX.md`, overview và đúng những note liên quan. Cuối task, `context-update` sửa đúng section bị ảnh hưởng. `context-update` từ chối ghi nếu một máy khác đã cập nhật note mới hơn. Session note đặt tên `<yyyy-mm-dd>_<machineId>.md` nên nhiều máy ít bị xung đột.

Không ghi secret, token, dữ liệu khách hàng hoặc đoạn code dài vào vault. hd-skill không tự đồng bộ vault; hãy dùng Obsidian Sync, Git hoặc OneDrive/Google Drive tuỳ bạn.

## 🔄 Cập nhật · 🩺 Chẩn đoán · 🗑️ Gỡ cài

| Việc | Lệnh |
|---|---|
| Cập nhật skill / đổi agent | Chạy lại **lệnh 1** |
| Đổi vault | Chạy lại **lệnh 2** |
| Kiểm tra cài đặt | `& "$env:USERPROFILE\.hd-skill\repo\doctor.ps1"` |
| Gỡ bản Global | `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1))) -Scope Global -Uninstall` |
| Gỡ khỏi dự án | `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1))) -Scope Project -Uninstall` |

Thêm `-DryRun` vào lệnh gỡ để xem trước. Khi gỡ, hd-skill chỉ xoá những gì nó đã tạo: junction/bản copy skill, khối `BEGIN/END hd-skill` trong file rule và mục MCP của nó. File bạn tự sửa vẫn được giữ, và mọi bản sao lưu nằm ở `%USERPROFILE%\.hd-skill\backups\`.

---

<details>
<summary><b>⚙️ Nâng cao: script trực tiếp, cấu hình, MCP</b></summary>

### Script trong checkout

`get.ps1` clone repo vào `%USERPROFILE%\.hd-skill\repo` (hoặc pull nếu đã có), rồi chạy `bootstrap.ps1` (Global) hoặc `install-project.ps1` (Project). Có thể gọi trực tiếp các script này. `install.ps1`, `update.ps1`, `uninstall.ps1` và `install-project.ps1` mặc định **chỉ in kế hoạch**; thêm `-Apply` để thực hiện.

```powershell
$repo = Join-Path $env:USERPROFILE '.hd-skill\repo'
& "$repo\install.ps1" -DryRun -Agents claude,codex
& "$repo\install.ps1" -Apply  -Agents claude,codex
& "$repo\update.ps1"  -Apply
& "$repo\install-project.ps1" -ProjectPath D:\code\my-app -Agents claude -Apply
```

| Tham số | Tác dụng |
|---|---|
| `-Agents <id,...>` | Chọn agent. `all` = tất cả, `detected` = quay về tự phát hiện. Được lưu làm lựa chọn mặc định. |
| `-DryRun` / `-Apply` | Xem kế hoạch / thực hiện |
| `-Mode Junction` | Mặc định: skill là junction trỏ về repo, luôn mới nhất |
| `-Mode Copy` | Sao chép skill khi môi trường không hỗ trợ junction |
| `-VaultPath <path>` | Chọn vault cho lần chạy này (dùng nháy nếu có dấu cách) |
| `-WithMcp` | Ghi cấu hình filesystem MCP cho Codex/Antigravity (cần Node.js). Với Claude Code, installer in sẵn lệnh `claude mcp add` để bạn chạy. |
| `-NonInteractive` | Không hỏi; nếu không xác định được vault thì dùng `.context\` |

### Thứ tự ưu tiên cấu hình

1. Tham số lệnh (`-VaultPath`, `-Agents`)
2. Biến môi trường `HD_SKILL_VAULT`, `HD_SKILL_AGENTS`, `HD_SKILL_HOME`
3. Cấu hình máy `%USERPROFILE%\.hd-skill\config.json` (không commit)
4. Tự phát hiện agent và vault (`%APPDATA%\obsidian\obsidian.json`, ưu tiên vault tên `DevBrain`)
5. Mặc định trong [config.defaults.json](config.defaults.json), lược đồ trong [config.schema.json](config.schema.json)

Xem cấu hình resolver sẽ dùng:

```powershell
& .\scripts\Resolve-HdSkillConfig.ps1 -RepoRoot $PWD | ConvertFrom-Json | Format-List vaultPath, contextMode, agents, selectedAgents, machineId
```

### Cách installer ghi file

Trước khi sửa file cấu hình agent, installer sao lưu vào `%USERPROFILE%\.hd-skill\backups\<timestamp>\`. Rule được ghép trong khối `BEGIN/END hd-skill`, nội dung ngoài khối giữ nguyên. Installer từ chối ghi đè skill trùng tên không do nó quản lý. Ở chế độ Project, file skill bạn đã sửa tay được giữ lại kèm cảnh báo.

</details>

<details>
<summary><b>🛠️ Xử lý sự cố</b></summary>

| Triệu chứng | Cách xử lý |
|---|---|
| Agent không thấy skill | Khởi động lại agent; chạy `doctor.ps1`; chạy lại lệnh 1 và kiểm tra agent đó có `[x]` không. |
| Agent không có trong menu | Thêm vào `%USERPROFILE%\.hd-skill\agents.custom.json` (xem [Thêm AI của riêng bạn](#-thêm-ai-của-riêng-bạn)). |
| `Unknown agent id(s)` | Sai `id` trong `-Agents` / `HD_SKILL_AGENTS`; lỗi in ra danh sách id hợp lệ. |
| `Refusing to replace an unmanaged skill` | Đã có thư mục skill cùng tên không do hd-skill tạo. Di chuyển nó đi rồi chạy lại. |
| Chọn sai vault hoặc đang dùng `.context\` | Chạy lại lệnh 2 hoặc truyền `-VaultPath`. |
| `git pull --ff-only` dừng | Repo `%USERPROFILE%\.hd-skill\repo` có thay đổi cục bộ: `git -C <repo> status`, xử lý rồi chạy lại. |
| PowerShell chặn script | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>` nếu chính sách cho phép. |
| Junction lỗi | Gỡ cài, rồi cài lại với `-Mode Copy`. |
| MCP không khởi động | Cần Node.js/npx và vault hợp lệ; xem `doctor.ps1`. Không cần MCP thì cài lại không có `-WithMcp`. |
| `context-update` từ chối ghi | Note đã được máy khác cập nhật; đọc lại note rồi thử lại. |

</details>

<details>
<summary><b>🗂️ Cấu trúc repo và kiểm chứng</b></summary>

```text
agents.json              Danh sách agent: đường dẫn skill/rule, cách phát hiện
get.ps1                  Lệnh 1: cài skill (irm | iex)
obsidian.ps1             Lệnh 2: kết nối vault Obsidian
install.ps1              Cài Global · install-project.ps1  Cài Project
update.ps1 · uninstall.ps1 · doctor.ps1 · bootstrap.ps1
rules/                   Rule dùng chung (AGENTS.md, GEMINI.md)
skills/                  Bộ skill chia sẻ
scripts/                 Resolver, phát hiện môi trường, validator
vault-template/          Mẫu cấu trúc vault
tests/                   Fixture và kiểm thử profile Windows giả lập
```

Thêm skill: tạo `skills/<tên>/SKILL.md` với frontmatter `name` (trùng tên thư mục) và `description`; thân skill dưới 300 dòng, UTF-8 không BOM. Chạy kiểm chứng (chỉ dùng profile tạm, không đụng tài khoản thật):

```powershell
& .\scripts\validate.ps1 -RootPath .\skills
& .\tests\verify-m1.ps1; & .\tests\verify-m2.ps1; & .\tests\verify-m3.ps1; & .\tests\verify-m4.ps1
& .\tests\machines\verify-machines.ps1
& .\tests\machines\verify-mcp-dryrun.ps1
& .\tests\machines\verify-install-lifecycle.ps1
& .\tests\machines\verify-bootstrap-update.ps1
& .\tests\machines\verify-agent-selection.ps1
```

</details>
