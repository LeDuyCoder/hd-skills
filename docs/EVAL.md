# Đánh giá context store trên fixture

Ngày chạy: 2026-10-17. Fixture: `tests/fixtures/demo-node`. So sánh ba tác vụ bằng cách lần theo đúng file mà agent cần đọc khi có note bootstrap (`tests/output`) và khi chỉ có repo mã nguồn. Đây là mô phỏng có kiểm soát trên file, không phải số đo từ phiên Codex/Antigravity trực tiếp.

## Cách đếm

- Một lần mở file được tính là một lần đọc; thao tác liệt kê/tìm file cần trước khi biết đường dẫn tính thêm một lần gọi công cụ.
- Token ước lượng = tổng ký tự UTF-8 đã giải mã của các file được mở, chia 4 và làm tròn lên. Không tính system prompt, câu hỏi, kết quả lệnh liệt kê, token hóa riêng của model, cache, hay suy luận. Đây chỉ là proxy để so độ dài ngữ cảnh đọc.
- Tác vụ có context vẫn đọc mã nguồn khi note ghi rõ thông tin chưa được xác minh. Không dùng ghi chú bootstrap như bằng chứng về hành vi.

## Kết quả

| Tác vụ | Có context: file đọc | Tool calls | Ký tự / token ước lượng | Không context: file đọc | Tool calls | Ký tự / token ước lượng | Kết quả |
|---|---|---:|---:|---|---:|---:|---|
| Stack và lệnh test/chạy | `00-INDEX.md`, `overview.md` | 2 | 2.563 / 641 | `README.md`, `package.json` | 2 | 413 / 104 | Cả hai tìm được Node.js và scripts; `package.json` là nguồn kiểm chứng cuối. |
| Luồng greeting và hành vi tên rỗng | `architecture.md`, `modules/src.md`, `src/index.js`, `src/greeting.js` | 4 | 2.238 / 560 | Liệt kê `src`, rồi `src/index.js`, `src/greeting.js` | 3 | 378 / 95 | Note chỉ là kiểm kê ban đầu, nên cả hai phải đọc mã. `run` gọi `greet`; tên được trim và rỗng trở thành `world`. |
| Phạm vi smoke test và lệnh chạy | `overview.md`, session note, `tests/smoke.js` | 3 | 3.371 / 843 | Liệt kê `tests`, rồi `package.json`, `tests/smoke.js` | 3 | 424 / 106 | Cả hai phát hiện test kiểm tra lời chào mặc định và tên `Codex`; manifest chỉ định `npm run test`. |
| **Tổng** |  | **9** | **8.172 / 2.044** |  | **8** | **1.215 / 305** | Fixture nhỏ chưa cho thấy tiết kiệm token; note sinh tự động chứa nhiều hướng dẫn xác minh và chưa ghi hành vi đã kiểm tra. |

## Nhận xét

Trong fixture này, context store không giảm số lần đọc công cụ và làm tăng lượng văn bản đọc khoảng 6,7 lần theo proxy ký tự/4. Nguyên nhân là note bootstrap là bản đồ cấu trúc có chủ ý, không tự suy diễn hành vi; với một dự án cực nhỏ, đọc trực tiếp manifest và hai file nguồn rẻ hơn. Lợi ích kỳ vọng nằm ở repo lớn hơn, nơi index/overview trỏ agent tới đúng module và quyết định thay vì quét toàn repo. Cần đánh giá lại trên dự án thực có nhiều module và ADR trước khi kết luận mức tiết kiệm.

## Trạng thái cài đặt máy thật

`docs/INSTALL-DRYRUN.log` lưu kế hoạch cài đặt trên máy hiện tại. DryRun không tạo file, junction, backup hay cấu hình. Phát hiện được cả Codex và Antigravity; không tìm thấy vault tên `DevBrain`, nên context mode dự kiến là `.context` trong repo; MCP tắt. Không chạy cài đặt thật trong lượt này: đang chờ người dùng xem log và cho phép bước ghi vào hồ sơ Windows.
