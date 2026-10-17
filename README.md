# hd-skill

`hd-skill` là bộ skill dùng chung cho Codex và Google Antigravity trên Windows. Repo chứa skill, rules, mẫu note và script; cấu hình riêng của máy nằm ở `%USERPROFILE%\.hd-skill\config.json`. Repo không chứa đường dẫn vault của một máy cụ thể.

## Cài trên máy mới

Cần Git và Windows PowerShell 5.1 trở lên. Node.js chỉ cần nếu bật MCP; hd-skill không tự cài công cụ phụ trợ. Vì repo chưa gắn remote mặc định, lệnh dưới đây hỏi Git URL đã được nhóm xác nhận, clone vào thư mục người dùng rồi chạy bootstrap:

```powershell
$repoUrl = Read-Host 'Git URL của repo hd-skill'; $repoHome = Join-Path $env:USERPROFILE '.hd-skill\repo'; if (-not (Test-Path -LiteralPath $repoHome)) { git clone $repoUrl $repoHome; if ($LASTEXITCODE -ne 0) { throw 'git clone failed' } }; & (Join-Path $repoHome 'bootstrap.ps1') -RepositoryUrl $repoUrl -Mode Junction
```

Bootstrap phát hiện agent và vault, lưu kết quả vào cấu hình máy, sau đó cài cho agent hiện có. Nếu chưa muốn ghi gì, thêm `-DryRun`. Muốn chỉ dùng Codex, Antigravity, hoặc cả hai thì cài ứng dụng tương ứng trước; installer chỉ cài skill cho ứng dụng được phát hiện. Antigravity dùng `%USERPROFILE%\.gemini\config\skills\`; vị trí skill cũ nếu có chỉ được báo cáo.

Để gọi bootstrap từ một checkout đã có:

```powershell
& .\bootstrap.ps1 -Mode Junction
& .\bootstrap.ps1 -DryRun -NonInteractive -Mode Copy
```

`bootstrap.ps1` áp dụng thay đổi sau khi clone/pull và kiểm tra repo. Lệnh trực tiếp `install.ps1`, `update.ps1`, `uninstall.ps1` mặc định chỉ in kế hoạch; dùng `-Apply` để thực hiện. Không cần quyền admin. Mọi file cấu hình toàn cục được sao lưu vào `%USERPROFILE%\.hd-skill\backups\<timestamp>\` trước khi sửa; rule dạng văn bản được quản lý trong khối `BEGIN/END hd-skill`.

## Cấu hình máy và vault

Thứ tự chọn cấu hình là tham số lệnh, biến môi trường, file máy, tự phát hiện, rồi mặc định repo. Các biến được hỗ trợ:

```powershell
$env:HD_SKILL_HOME = Join-Path $env:USERPROFILE '.hd-skill\repo'
$env:HD_SKILL_VAULT = 'đường dẫn vault trên máy này'
```

`install.ps1 -VaultPath <path>` có ưu tiên cao hơn biến môi trường. Lần đầu, `install.ps1` phát hiện và in tóm tắt rồi lưu cấu hình vào `%USERPROFILE%\.hd-skill\config.json`. Có thể đọc kết quả phân giải mà không cài:

```powershell
& .\scripts\Resolve-HdSkillConfig.ps1 -RepoRoot $PWD | ConvertFrom-Json | Format-List vaultPath, contextMode, agents, machineId
```

Mặc định tên vault là `DevBrain`. Resolver đọc danh sách từ `%APPDATA%\obsidian\obsidian.json`, dùng vault trùng tên, hoặc hỏi chọn nếu có nhiều vault khác tên. Trong `-NonInteractive`, nếu không xác định được vault phù hợp thì dùng `.context\` trong repo. Không có Obsidian vẫn dùng được. Đường dẫn OneDrive/Documents không được suy đoán; chỉ chọn vault từ cấu hình Obsidian, `-VaultPath`, biến môi trường hoặc config máy.

MCP tắt theo mặc định; thao tác đọc/ghi file gốc của agent là phương án mặc định. `-WithMcp` chỉ sinh cấu hình filesystem MCP đã pin phiên bản, sau khi phát hiện Node.js và vault truy cập được. Kiểm tra kế hoạch cấu hình mà không ghi:

```powershell
& .\install.ps1 -DryRun -WithMcp
```

## Dùng với Codex

Các skill được đưa vào `%USERPROFILE%\.agents\skills\`. Rule toàn cục nằm trong `%USERPROFILE%\.codex\AGENTS.md` và yêu cầu agent gọi `context-load` trước khi tìm hiểu dự án. Mở repo dự án trong Codex rồi yêu cầu trực tiếp công việc; Codex sẽ chọn skill theo phần mô tả trong từng `SKILL.md`. Có thể mở `/skills` để kiểm tra danh sách.

## Dùng với Antigravity

Các skill được đưa vào `%USERPROFILE%\.gemini\config\skills\`, rule vào `%USERPROFILE%\.gemini\config\GEMINI.md`. Khởi động lại hoặc làm mới Antigravity sau cài đặt để nạp skill. Installer không tự tạo junction tới đường dẫn skill cũ.

## Thêm dự án và dùng bộ nhớ ngữ cảnh

Trong repo dự án, chạy skill `context-bootstrap` để nhận diện stack và sinh note khởi đầu. `context-load` đọc index/overview rồi chỉ mở note liên quan; `context-audit` so `last_verified_commit` với `git log`; `context-update` cập nhật đúng phần note liên quan và từ chối ghi nếu trường `updated` cho thấy một máy khác đã ghi phiên bản mới hơn. Session note dùng tên `<yyyy-mm-dd>_<machineId>.md`. Note lưu đường dẫn repo tương đối hoặc tên remote Git, không ghi đường dẫn tuyệt đối máy.

Nếu cần lưu đường dẫn checkout cục bộ cho một dự án, ghi `projects` trong config riêng của máy. Không commit config đó.

## Thêm skill

Tạo `skills/<skill-name>/SKILL.md` với YAML frontmatter `name` và `description`. `name` phải bằng tên thư mục; nội dung dưới 300 dòng; UTF-8 không BOM. Description dài hơn 300 ký tự sẽ được cảnh báo. Có thể đặt script PowerShell riêng bên trong thư mục skill. Kiểm tra trước khi commit:

```powershell
& .\scripts\validate.ps1 -RootPath .\skills
```

Skill được cập nhật trong repo dùng chung sẽ được đưa sang agent khi chạy `update.ps1 -Apply` hoặc bootstrap lại.

## Đồng bộ giữa các máy

Repo hd-skill đồng bộ qua Git. Chạy `update.ps1 -DryRun` để xem kế hoạch, rồi `update.ps1 -Apply` để pull, validate và cài lại; cấu hình máy được giữ nguyên.

Vault là dữ liệu cá nhân, hd-skill không tự đồng bộ vault. Chọn một cơ chế đồng bộ cho cùng vault:

- **Obsidian Sync:** cấu hình cùng vault trong Obsidian trên từng máy; để resolver tự tìm theo tên `DevBrain`.
- **Git:** khởi tạo Git trong vault, đồng bộ commit/pull theo quy trình nhóm. Trước khi merge session note, giữ file theo tên máy riêng; nếu có conflict ở note dùng chung, giải quyết theo section và kiểm tra `updated`.
- **OneDrive hoặc Google Drive:** đặt vault trong thư mục đồng bộ do người dùng chọn và kiểm tra Obsidian nhận đúng đường dẫn trên từng máy. Không dựa vào đường dẫn Documents cố định vì vị trí có thể thay đổi.

Session của mỗi máy dùng `machineId` riêng. Các cập nhật context chỉ sửa section được yêu cầu, khóa file trong lúc ghi và so timestamp trước khi thay. Hãy pull/đồng bộ trước khi làm việc offline lâu; nếu helper báo note đã mới hơn, đọc lại note rồi thử cập nhật lại.

## Chẩn đoán và gỡ cài

```powershell
& .\doctor.ps1
& .\uninstall.ps1 -DryRun
& .\uninstall.ps1 -Apply
```

Doctor báo tình trạng config, vault/fallback, junction/copy, agent, MCP (nếu bật) và Git; mỗi lỗi có cách sửa. Gỡ cài chỉ bỏ link/copy và mục do hd-skill quản lý; file người dùng khác được giữ lại. Bản sao lưu config nằm trong `.hd-skill\backups`.

## Công cụ còn thiếu

- Cài Git for Windows để clone, pull và kiểm tra lịch sử repo.
- Cài Node.js LTS để dùng Node/npm/npx hoặc bật MCP.
- PowerShell 7 được khuyến nghị cho môi trường mới; các script hiện vẫn có kiểm chứng tương thích Windows PowerShell 5.1. Tải từ trang phát hành chính thức PowerShell nếu cần.
- Codex CLI/IDE và Antigravity là ứng dụng riêng; cài ứng dụng cần dùng trước. Installer không tải hoặc cài ứng dụng.

Không có bước nào tự cài phần mềm. MCP filesystem là tuỳ chọn và không được bật bởi cài mặc định.
