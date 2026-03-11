# ỨNG DỤNG GIẢI ĐẤU PICKLEBALL
## Tài Liệu Kiến Trúc Hợp Nhất

**Phiên bản:** 1.0
**Ngày:** Tháng 3, 2026
**Công nghệ:** .NET 8 + React + React Native

---

## 1. Tổng Quan Sản Phẩm

### 1.1. Mô tả

Ứng dụng quản lý giải đấu pickleball toàn diện, hỗ trợ:
- Tạo và quản lý giải đấu theo thể thức Round Robin (Vòng tròn)
- Đấu đơn (Singles) và đấu đôi (Doubles)
- Cộng đồng người chơi: tạo game giao hữu, tìm trận, giao lưu
- Chat real-time, thông báo, xếp hạng

### 1.2. Đối tượng sử dụng

| Vai trò | Mô tả | Quyền hạn |
|---------|-------|-----------|
| **Admin** | Quản trị hệ thống | Quản lý toàn bộ hệ thống, người dùng, nội dung |
| **Creator (Organizer)** | Người tạo giải đấu | Toàn quyền với giải: mời, duyệt, xếp bảng, nhập điểm, hủy giải |
| **Player** | Người tham gia giải | Xin vào giải, xem lịch đấu, xem kết quả, tạo game cộng đồng |
| **User (Guest)** | Người dùng chưa tham gia giải | Duyệt giải đấu, xin tham gia, xem thông tin công khai |

---

## 2. Công Nghệ Sử Dụng (Tech Stack)

### 2.1. Kiến trúc tổng thể

```
                    +-------------------+
                    |   React (Vite)    |  Web App
                    |   TypeScript      |
                    |   TailwindCSS     |
                    +--------+----------+
                             |
                             |  REST API + SignalR
                             |
+-------------------+        |        +-------------------+
| React Native      |--------+--------|  .NET 8 Web API   |  Backend
| Expo + TS         |  Mobile App     |  EF Core          |
+-------------------+                 |  SignalR           |
                                      +--------+----------+
                                               |
                              +----------------+----------------+
                              |                |                |
                     +--------+---+   +--------+---+   +-------+------+
                     | PostgreSQL |   |  Redis     |   | Cloudinary   |
                     | Database   |   |  Cache     |   | Storage(Free)|
                     +------------+   +------------+   +--------------+
```

### 2.2. Chi tiết công nghệ

| Thành phần | Công nghệ | Mục đích |
|-------|-----------|----------|
| **Backend** | .NET 8 Web API | REST API, xử lý logic nghiệp vụ |
| **ORM** | Entity Framework Core | Truy cập cơ sở dữ liệu |
| **Realtime** | SignalR | Tỉ số trực tiếp, chat, thông báo |
| **Web Frontend** | React (Vite) + TypeScript + TailwindCSS | Ứng dụng Web |
| **Mobile** | React Native (Expo) + TypeScript | Ứng dụng iOS & Android |
| **Database** | PostgreSQL | Lưu trữ dữ liệu chính |
| **Cache** | Redis | Cache dashboard, xếp hạng, phiên làm việc |
| **Storage** | Cloudinary (Gói miễn phí) | Avatar, banner, ảnh chứng minh điểm |
| **Auth** | JWT + Refresh Token | Xác thực & phân quyền |
| **Push Notification** | FCM (Firebase Cloud Messaging) | Thông báo đẩy trên mobile |
| **Queue** | Background Service (.NET) hoặc RabbitMQ | Các tác vụ bất đồng bộ (tính xếp hạng, thông báo) |

### 2.3. Cấu trúc project Backend (.NET 8)

```
PickleballApp/
├── src/
│   ├── PickleballApp.API/              # Tầng API (Controllers, Middleware, Filters)
│   │   ├── Controllers/
│   │   ├── Middleware/
│   │   ├── Hubs/                       # SignalR Hubs
│   │   └── Program.cs
│   ├── PickleballApp.Application/      # Logic nghiệp vụ (Services, DTOs, Validators)
│   │   ├── Services/
│   │   ├── DTOs/
│   │   ├── Interfaces/
│   │   └── Validators/
│   ├── PickleballApp.Domain/           # Các thực thể domain, enums, value objects
│   │   ├── Entities/
│   │   ├── Enums/
│   │   └── ValueObjects/
│   └── PickleballApp.Infrastructure/   # EF Core, Redis, Cloudinary, FCM, Các dịch vụ bên ngoài
│       ├── Data/
│       ├── Repositories/
│       ├── Services/
│       └── Migrations/
├── tests/
│   ├── PickleballApp.UnitTests/
│   └── PickleballApp.IntegrationTests/
└── PickleballApp.sln
```

### 2.4. Cấu trúc project Web (React)

```
pickleball-web/
├── src/
│   ├── api/                  # API client, cấu hình axios
│   ├── assets/               # Hình ảnh, icons, fonts
│   ├── components/           # Các component UI dùng chung
│   │   ├── ui/               # Button, Input, Modal, Card...
│   │   ├── layout/           # Header, Footer, Sidebar, BottomNav
│   │   └── common/           # BracketView, ScoreInput, PlayerCard...
│   ├── features/             # Các mô-đun tính năng
│   │   ├── auth/
│   │   ├── tournament/
│   │   ├── match/
│   │   ├── community/
│   │   ├── chat/
│   │   ├── profile/
│   │   └── notification/
│   ├── hooks/                # Các hook tùy chỉnh
│   ├── lib/                  # Tiện ích, trình hỗ trợ
│   ├── routes/               # Cấu hình React Router
│   ├── stores/               # Quản lý trạng thái (Zustand)
│   └── types/                # Các kiểu dữ liệu TypeScript
├── public/
├── index.html
├── vite.config.ts
├── tailwind.config.ts
└── package.json
```

---

## 3. Mô-đun & Tính Năng Hợp Nhất

### 3.1. Tổng quan mô-đun

| # | Mô-đun | Số tính năng | Trọng tâm | Giai đoạn |
|---|--------|:-----------:|-----------|:-----:|
| M1 | Auth & Profile | 6 | Đăng ký, đăng nhập, hồ sơ, lịch sử, theo dõi | 1 |
| M2 | Quản lý Giải đấu | 13 | Tạo/sửa/hủy giải, mời/duyệt người chơi, ghép cặp, xếp bảng | 1 |
| M3 | Trận đấu & Ghi điểm | 5 | Lịch thi đấu, nhập điểm, BXH, kết quả, tỉ số trực tiếp | 1 |
| M4 | Khám phá & Tìm kiếm | 3 | Duyệt giải đấu, chi tiết giải, xem sơ đồ thi đấu | 1 |
| M5 | Cộng đồng | 7 | Tạo/tham gia game giao hữu, sảnh chờ, mời chơi | 2 |
| M6 | Chat | 2 | Chat 1-1, chat nhóm, thời gian thực | 2 |
| M7 | Thông báo | 2 | Push + trong ứng dụng, deep link, đếm số thông báo | 1 |
| | **Tổng cộng** | **38** | | |

---

### 3.2. Mô-đun 1: Auth & Profile (6 tính năng)

#### M1-F1. Đăng ký / Đăng nhập

- **API:** `POST /api/auth/register` — Tạo tài khoản (email, mật khẩu, tên, ảnh đại diện)
- **API:** `POST /api/auth/login` — Xác thực, trả về JWT
- **API:** `POST /api/auth/social` — OAuth2 (Google, Apple)
- **API:** `POST /api/auth/refresh` — Làm mới mã thông báo (Refresh token)
- **Frontend:** Màn hình đăng ký/đăng nhập: email + mật khẩu, các nút đăng nhập mạng xã hội, quên mật khẩu
- **Lưu ý:**
  - JWT access token (15 phút) + refresh token (7 ngày)
  - Hash mật khẩu bằng bcrypt
  - Giới hạn tốc độ đăng nhập (Rate limit): 5 lần / 15 phút

#### M1-F2. Quản lý hồ sơ cá nhân

- **API:** `GET /api/users/me` — Đọc hồ sơ
- **API:** `PUT /api/users/me` — Cập nhật hồ sơ (tên, ảnh đại diện, tiểu sử, trình độ, tay thuận, loại vợt)
- **Frontend:** Trang hồ sơ: tải lên + cắt ảnh đại diện, tên, tiểu sử, trình độ (1.0-5.0), thống kê
- **Lưu ý:**
  - Ảnh đại diện thay đổi kích thước 256x256, nén trước khi tải lên Cloudinary
  - Trình độ ban đầu do người dùng tự đánh giá, sau đó hệ thống sẽ điều chỉnh

#### M1-F3. Đổi mật khẩu

- **API:** `PUT /api/auth/password` — Kiểm tra mật khẩu cũ, hash mật khẩu mới, hủy tất cả mã thông báo cũ
- **Frontend:** Biểu mẫu đổi mật khẩu: mật khẩu cũ, mật khẩu mới (có thước đo độ mạnh), xác nhận
- **Lưu ý:** Chính sách mật khẩu: tối thiểu 8 ký tự, có chữ hoa, số, ký tự đặc biệt

#### M1-F4. Xem lịch sử giải đấu

- **API:** `GET /api/users/me/tournaments` — Danh sách giải đã tham gia/tạo, kèm kết quả
- **Frontend:** Tab "Giải của tôi": lọc (đã tạo / đã tham gia / đang diễn ra / đã kết thúc)
- **Lưu ý:** Phân trang dạng cuộn vô hạn (infinite scroll). Có huy hiệu cho giải vô địch.

#### M1-F5. Theo dõi (Following / Followers)

- **API:** `GET /api/users/me/following` — Danh sách đang theo dõi
- **API:** `GET /api/users/me/followers` — Danh sách người theo dõi
- **API:** `POST /api/users/:id/follow` — Theo dõi
- **API:** `DELETE /api/users/:id/follow` — Bỏ theo dõi
- **Frontend:** Các tab Đang theo dõi/Người theo dõi: thẻ người dùng, nút theo dõi/bỏ theo dõi, huy hiệu theo dõi chéo
- **Lưu ý:** Cập nhật UI theo hướng lạc quan (Optimistic UI update). Cuộn vô hạn.

#### M1-F6. Xem hồ sơ người khác

- **API:** `GET /api/users/:id/profile` — Tiểu sử, thành tích, thống kê
- **API:** `GET /api/users/:id/matches` — Lịch sử trận đấu
- **Frontend:** Trang hồ sơ: ảnh đại diện, tiểu sử, thống kê, lịch sử trận đấu, thành tích đối đầu
- **Lưu ý:** Tôn trọng cài đặt quyền riêng tư. Chỉ hiển thị thông tin người dùng cho phép công khai.

---

### 3.3. Mô-đun 2: Quản lý Giải đấu (13 tính năng)

#### M2-F1. Tạo giải đấu mới

- **API:** `POST /api/tournaments`
- **Đầu vào:** tên giải (bắt buộc), mô tả, loại (đơn/đôi), số bảng (đơn: 1-4, đôi: 1-2), định dạng ghi điểm (best_of_1 / best_of_3), ngày, địa điểm, ảnh bìa
- **Trạng thái ban đầu:** `draft`
- **Frontend:** Biểu mẫu tạo giải với bộ chọn trực quan số bảng (hiển thị sơ đồ bảng khi chọn)
- **Lưu ý:**
  - Kiểm tra (Validate): đơn tối đa 4 bảng, đôi tối đa 2 bảng
  - Hiển thị "Cần tối thiểu X người/đội để bắt đầu" (số bảng x 4)
  - Cho phép lưu bản nháp

#### M2-F2. Chỉnh sửa giải đấu

- **API:** `PUT /api/tournaments/:id` — Chỉ dành cho người tạo (creator)
- **Frontend:** Biểu mẫu chỉnh sửa (điền sẵn), các trường bị khóa sẽ hiển thị mờ
- **Lưu ý:**
  - Khóa: loại giải, số bảng (sau khi đã có >=1 người tham gia)
  - Thông báo cho người tham gia khi có thay đổi quan trọng (ngày, địa điểm)

#### M2-F3. Hủy giải đấu

- **API:** `DELETE /api/tournaments/:id` — Xóa mềm, chỉ dành cho người tạo
- **Frontend:** Hộp thoại xác nhận + lý do → thông báo cho tất cả người tham gia
- **Lưu ý:** Giải đang mở đăng ký → hủy OK. Giải đang thi đấu → cảnh báo mạnh + bắt buộc nhập lý do.

#### M2-F4. Quản lý trạng thái giải đấu

- **API:** `PUT /api/tournaments/:id/status`
- **Luồng (Flow):**

```
draft → open → ready → in_progress → completed
                                         ↓
                                      cancelled (bất kỳ lúc nào trước completed)
```

| Trạng thái | Ý nghĩa | Điều kiện chuyển tiếp |
|------------|---------|----------------------|
| `draft` | Bản nháp, chưa công khai | Người tạo nhấn "Xuất bản" |
| `open` | Đang nhận đăng ký | Đủ người + Người tạo nhấn "Đóng đăng ký" |
| `ready` | Đã xếp bảng, sẵn sàng | Người tạo nhấn "Bắt đầu giải" |
| `in_progress` | Đang thi đấu | Tất cả trận đấu hoàn thành |
| `completed` | Đã kết thúc | Tự động |
| `cancelled` | Đã hủy | Người tạo hủy |

- **Lưu ý:** Không cho phép nhảy cóc trạng thái. Mỗi bước chuyển cần kiểm tra điều kiện.

#### M2-F5. Mời người chơi (Creator)

- **API:** `POST /api/tournaments/:id/invite`
- **Frontend:** Tìm kiếm người dùng → nút "Mời" → Danh sách đã mời (đang chờ/đã chấp nhận/đã từ chối)
- **Lưu ý:**
  - Giới hạn: không vượt quá sức chứa tối đa (số bảng x 4 cho đấu đơn, số bảng x 4 x 2 cho đấu đôi)
  - Người dùng nhận được thông báo đẩy

#### M2-F6. Xin tham gia (User)

- **API:** `POST /api/tournaments/:id/request`
- **Frontend:** Nút "Xin tham gia" → Xác nhận → Hiển thị "Đang chờ duyệt"
- **Lưu ý:** Một người dùng chỉ gửi 1 yêu cầu / giải. Kiểm tra: giải đang ở trạng thái "open", chưa đầy.

#### M2-F7. Duyệt yêu cầu tham gia (Creator)

- **API:** `PUT /api/tournaments/:id/requests/:requestId` — Chấp nhận/Từ chối
- **Frontend:** Tab "Yêu cầu chờ duyệt" (có đếm số lượng): ảnh đại diện, tên, bảng xếp hạng → Duyệt/Từ chối
- **Lưu ý:** Kiểm tra số chỗ còn trống trước khi duyệt. Từ chối có thể kèm lý do (tùy chọn).

#### M2-F8. Xem danh sách người tham gia

- **API:** `GET /api/tournaments/:id/participants`
- **Frontend:** Danh sách: ảnh đại diện, tên, bảng xếp hạng, trạng thái. Bộ đếm "X/Y người"
- **Lưu ý:** Chỉ người tạo mới thấy nút xóa. Xóa người sau khi đã xếp bảng thì phải xếp lại.

#### M2-F9. Rời giải / Xóa người chơi

- **API:** `DELETE /api/tournaments/:id/participants/:userId`
- **Frontend:** Người chơi: "Rời giải" → Xác nhận. Người tạo: "Xóa" → Xác nhận + lý do
- **Lưu ý:** Không cho phép rời/xóa khi giải đang trong quá trình thi đấu (in_progress). Dùng walkover (xử thắng) cho các trận còn lại.

#### M2-F10. Ghép đôi thủ công (Chỉ dành cho Đấu Đôi)

- **API:** `POST /api/tournaments/:id/teams`
- **Frontend:** Giao diện kéo thả: danh sách người chưa ghép → kéo vào ô của đội
- **Lưu ý:** Phải ghép hết tất cả, không để thừa. Nếu số người lẻ → báo "Cần thêm 1 người".

#### M2-F11. Ghép đôi ngẫu nhiên (Chỉ dành cho Đấu Đôi)

- **API:** `POST /api/tournaments/:id/teams/random`
- **Frontend:** Nút "Ghép ngẫu nhiên" → Xem trước → "Chấp nhận" / "Ghép lại"
- **Lưu ý:** Sử dụng thuật toán Fisher-Yates shuffle. Chỉ lưu khi Người tạo xác nhận.

#### M2-F12. Xếp bảng thủ công

- **API:** `POST /api/tournaments/:id/groups`
- **Frontend:** Kéo thả người/đội vào các bảng (Bảng A, B, ...). Mỗi bảng 4 vị trí.
- **Lưu ý:** Khi xếp xong → hệ thống tự động tạo lịch đấu vòng tròn (Round Robin).

#### M2-F13. Xếp bảng ngẫu nhiên

- **API:** `POST /api/tournaments/:id/groups/random`
- **Frontend:** Nút "Xếp ngẫu nhiên" → Xem trước → "Chấp nhận" / "Xếp lại"
- **Lưu ý:** Xem trước kết quả, không lưu ngay. Người tạo có thể chỉnh sửa lại thủ công sau đó.

---

### 3.4. Mô-đun 3: Trận đấu & Ghi điểm (5 tính năng)

#### Quy tắc Vòng Tròn (Round Robin - mỗi bảng 4 đơn vị)

| Vòng | Trận 1 | Trận 2 |
|:----:|:------:|:------:|
| Vòng 1 | A vs B | C vs D |
| Vòng 2 | A vs C | B vs D |
| Vòng 3 | A vs D | B vs C |

- Mỗi bảng: 6 trận, 3 vòng
- Xếp hạng: (1) Số trận thắng → (2) Hiệu số điểm → (3) Đối đầu trực tiếp

#### Quy tắc Điểm Pickleball

- Thắng set khi đạt 11 điểm, phải thắng cách biệt 2 điểm
- Hỗ trợ: thắng 1 set (best of 1) hoặc thắng 2 trên 3 set (best of 3) (Người tạo chọn khi tạo giải)

#### M3-F1. Xem lịch thi đấu

- **API:** `GET /api/tournaments/:id/matches` — Được nhóm theo bảng và vòng
- **Frontend:** Các Tab (Bảng A, B, ...): mỗi bảng 3 vòng x 2 trận. Làm nổi bật trận tiếp theo.
- **Lưu ý:** Người chơi chỉ thấy lịch của bảng mình. Người tạo thấy tất cả.

#### M3-F2. Nhập điểm trận đấu (Creator)

- **API:** `POST /api/matches/:id/score`
- **Đầu vào:** điểm từng set (vd: [11-7, 9-11, 11-8])
- **Logic:** Kiểm tra điểm hợp lệ → xác định người thắng → cập nhật trạng thái trận đấu → cập nhật BXH
- **Frontend:** Màn hình nhập điểm: 2 bên, điểm từng set, nút "Thêm set", tự động nhận diện người thắng
- **Lưu ý:**
  - Kiểm tra: điểm >= 0, thắng set khi đạt 11 điểm và cách biệt ít nhất 2 điểm
  - Việc tính toán lại bảng xếp hạng chạy bất đồng bộ (background job)
  - **SignalR đẩy tỉ số trực tiếp (live score)** đến tất cả người đang xem

#### M3-F3. Sửa điểm trận đấu (Creator)

- **API:** `PUT /api/matches/:id/score`
- **Frontend:** Nút "Sửa điểm" → Biểu mẫu được điền sẵn → Xác nhận → Cập nhật BXH
- **Lưu ý:** Lưu nhật ký lịch sử sửa đổi. Tính toán lại BXH sau khi sửa.

#### M3-F4. Bảng xếp hạng bảng (Round Robin Standings)

- **API:** `GET /api/tournaments/:id/groups/:groupId/standings`
- **Cột:** Hạng, Tên, Thắng, Thua, Điểm ghi được, Điểm bị mất, Hiệu số
- **Frontend:** Bảng xếp hạng cập nhật thời gian thực (SignalR cập nhật khi có kết quả mới)
- **Tiêu chí ưu tiên khi bằng điểm (Tiebreaker):**
  1. Số trận thắng
  2. Hiệu số điểm (tổng điểm ghi được - tổng điểm bị mất)
  3. Đối đầu trực tiếp
  4. Nếu 3 người cùng số trận thắng → xét vòng tròn riêng giữa 3 người đó

#### M3-F5. Kết quả tổng giải

- **API:** `GET /api/tournaments/:id/results`
- **Frontend:** Bục vinh quang hạng 1 của mỗi bảng, kết quả từng bảng, thống kê chung của giải
- **Lưu ý:**
  - Tự động nhận diện hoàn thành: trận cuối cùng có điểm → chuyển trạng thái sang "completed"
  - Chia sẻ kết quả: tạo thẻ hình ảnh để chia sẻ lên mạng xã hội

---

### 3.5. Mô-đun 4: Khám phá & Tìm kiếm (3 tính năng)

#### M4-F1. Danh sách giải đấu

- **API:** `GET /api/tournaments` — Lọc theo: trạng thái, loại (đơn/đôi), tìm kiếm, phân trang
- **Frontend:** Thanh tìm kiếm + các nút lọc + thẻ giải đấu (tên, loại, ngày, địa điểm, X/tối đa người, trạng thái)
- **Lưu ý:** Sắp xếp mặc định: ưu tiên các giải đang mở đăng ký lên đầu. Giải đã đầy: ẩn nút "Xin tham gia".

#### M4-F2. Chi tiết giải đấu

- **API:** `GET /api/tournaments/:id` — Thông tin đầy đủ: giải đấu, các bảng, lịch đấu, kết quả, BXH
- **Frontend:** Các Tab: Tổng quan, Người tham gia, Lịch đấu, Kết quả. Các nút hành động tùy theo vai trò.
- **Lưu ý:** Thông tin hiển thị tùy thuộc vào trạng thái hiện tại của giải đấu.

#### M4-F3. Sơ đồ thi đấu (Bracket View - Tương tác)

- **API:** `GET /api/tournaments/:id/draw` — Dữ liệu sơ đồ thi đấu
- **Frontend:** Hình ảnh hóa sơ đồ thi đấu tương tác: các nút trận đấu, điểm số, phóng to/thu nhỏ/di chuyển
- **Lưu ý:** Sử dụng SVG hoặc canvas. Giai đoạn 1 chỉ hiển thị bảng Round Robin. Giai đoạn 3 mở rộng sơ đồ cho vòng loại trực tiếp (Elimination).

---

### 3.6. Mô-đun 5: Cộng đồng (7 tính năng) — Giai đoạn 2

#### M5-F1. Tạo game cộng đồng

- **API:** `POST /api/community/games`
- **Đầu vào:** tiêu đề, ngày/giờ, địa điểm (chọn trên bản đồ), số người tối đa, trình độ, mô tả
- **Frontend:** Biểu mẫu tạo game với bộ chọn Google Maps
- **Lưu ý:** Tự động tạo nhóm chat cho game này. Đặt múi giờ theo vị trí địa lý.

#### M5-F2. Sửa game

- **API:** `PUT /api/community/games/:id` — Kiểm tra, cập nhật, gửi thông báo
- **Frontend:** Biểu mẫu chỉnh sửa (điền sẵn), nút gạt để tùy chọn gửi thông báo hay không
- **Lưu ý:** Nếu có thay đổi lớn (ngày/giờ/địa điểm) → cho phép người chơi đã tham gia được quyền hủy tham gia.

#### M5-F3. Xóa game

- **API:** `DELETE /api/community/games/:id` — Xóa mềm, gửi thông báo
- **Frontend:** Cửa sổ xác nhận + lý do
- **Lưu ý:** Không cho phép xóa các game đang diễn ra hoặc đã kết thúc.

#### M5-F4. Mời người chơi vào game

- **API:** `POST /api/community/games/:id/invite`
- **Frontend:** Tìm/chọn người chơi, mời hàng loạt, tin nhắn tùy chỉnh
- **Lưu ý:** Gợi ý người chơi: đã từng chơi cùng, cùng trình độ, ở gần địa điểm game.

#### M5-F5. Tham gia game

- **API:** `POST /api/community/games/:id/join`
- **Frontend:** Nút tham gia → Xác nhận. Vào danh sách chờ nếu game đã đủ người.
- **Lưu ý:** Dùng database transaction để xử lý tranh chấp dữ liệu (race condition). Tự động đẩy người từ danh sách chờ lên khi có chỗ trống.

#### M5-F6. Xem chi tiết game

- **API:** `GET /api/community/games/:id`
- **Frontend:** Bản đồ, danh sách người chơi, bình luận, chia sẻ
- **Lưu ý:** Phần bình luận dùng để thảo luận trước khi game bắt đầu.

#### M5-F7. Sảnh chờ (Lobby) — Danh sách game

- **API:** `GET /api/community/lobby` — Lọc theo: ngày, địa điểm, trình độ, số chỗ còn trống
- **Frontend:** Thẻ thông tin game + bộ lọc + chuyển đổi chế độ xem bản đồ + sắp xếp
- **Lưu ý:** Sắp xếp mặc định theo khoảng cách địa lý. Chế độ bản đồ sử dụng nhóm các điểm đánh dấu (marker clustering).

---

### 3.7. Mô-đun 6: Chat (2 tính năng) — Giai đoạn 2

#### M6-F1. Danh sách chat

- **API:** `GET /api/chats` — Danh sách chat sắp xếp theo tin nhắn mới nhất, đếm số tin chưa đọc
- **Frontend:** Ảnh đại diện, tên, xem trước tin nhắn cuối, thời gian, huy hiệu tin chưa đọc, các hành động khi vuốt (swipe)
- **Thời gian thực:** SignalR cập nhật thứ tự và nội dung xem trước khi có tin nhắn mới

#### M6-F2. Chi tiết chat

- **API:** `GET /api/chats/:id/messages` — Tin nhắn được phân trang
- **Frontend:** Các bong bóng tin nhắn, ô nhập tin nhắn gửi đi, tệp đính kèm, hiệu ứng đang nhập tin nhắn, xác nhận đã đọc
- **Thời gian thực:** Các sự kiện SignalR: `MessageSend`, `MessageReceived`, `TypingStart`, `TypingStop`, `MessageRead`
- **Lưu ý:** Hàng chờ ngoại tuyến (Offline queue) cho tin nhắn gửi khi mất mạng. Tải chậm (Lazy load) các tin nhắn cũ.

---

### 3.8. Mô-đun 7: Thông báo (2 tính năng)

#### M7-F1. Danh sách thông báo

- **API:** `GET /api/notifications` — Phân trang, lọc theo: tất cả/chưa đọc/trận đấu/mạng xã hội
- **Frontend:** Nhóm theo loại: mời vào giải, kết quả, tin nhắn. Các nút hành động (Chấp nhận/Từ chối)
- **Lưu ý:** API đánh dấu đã đọc hàng loạt.

#### M7-F2. Thông báo đẩy (Push Notification)

- **Backend:** Tích hợp FCM, gửi push cho các sự kiện:
  - Lời mời vào giải đấu
  - Đơn xin tham gia được duyệt/từ chối
  - Lịch thi đấu đã được tạo
  - Kết quả trận đấu
  - Có tin nhắn mới
  - Giải đấu bị hủy
- **Lưu ý:** Dùng deep link từ thông báo để dẫn đến đúng màn hình tương ứng.

#### M6-F2. Chi tiết chat

- **API:** `GET /api/chats/:id/messages` — Tin nhắn được phân trang
- **Frontend:** Các bong bóng tin nhắn, ô nhập tin nhắn gửi đi, tệp đính kèm, hiệu ứng đang nhập tin nhắn, xác nhận đã đọc
- **Thời gian thực:** Các sự kiện SignalR: `MessageSend`, `MessageReceived`, `TypingStart`, `TypingStop`, `MessageRead`
- **Lưu ý:** Hàng chờ ngoại tuyến (Offline queue) cho tin nhắn gửi khi mất mạng. Tải chậm (Lazy load) các tin nhắn cũ.

---

### 3.8. Mô-đun 7: Thông báo (2 tính năng)

#### M7-F1. Danh sách thông báo

- **API:** `GET /api/notifications` — Phân trang, lọc theo: tất cả/chưa đọc/trận đấu/mạng xã hội
- **Frontend:** Nhóm theo loại: mời vào giải, kết quả, tin nhắn. Các nút hành động (Chấp nhận/Từ chối)
- **Lưu ý:** API đánh dấu đã đọc hàng loạt.

#### M7-F2. Thông báo đẩy (Push Notification)

- **Backend:** Tích hợp FCM, gửi push cho các sự kiện:
  - Lời mời vào giải đấu
  - Đơn xin tham gia được duyệt/từ chối
  - Lịch thi đấu đã được tạo
  - Kết quả trận đấu
  - Có tin nhắn mới
  - Giải đấu bị hủy
- **Lưu ý:** Dùng deep link từ thông báo để dẫn đến đúng màn hình tương ứng.

---

## 4. Sơ Đồ Cơ Sở Dữ Liệu (Database Schema)

### 4.1. ERD Tổng quan

```
Người dùng (Users) ──────────┬──── Giải đấu (Tournaments) (người tạo)
  │             │         │
  │             │    Người tham gia (Participants) ── Đội (Teams) (đôi)
  │             │         │
  │             │      Bảng (Groups) ── Thành viên bảng (GroupMembers)
  │             │         │
  │             │      Trận đấu (Matches)
  │             │
  ├── Theo dõi (Follows) (người theo dõi/được theo dõi)
  │
  ├── Game cộng đồng (CommunityGames) ── Người tham gia game (GameParticipants)
  │
  ├── Phòng chat (ChatRooms) ── Thành viên chat (ChatMembers) ── Tin nhắn (Messages)
  │
  └── Thông báo (Notifications)
```

### 4.2. Chi tiết bảng

```sql
-- =============================================
-- CỐT LÕI (CORE): Xác thực & Hồ sơ (Auth & Profile)
-- =============================================

CREATE TABLE Users (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Email           VARCHAR(255) UNIQUE NOT NULL,
    PasswordHash    VARCHAR(255) NOT NULL,
    Name            VARCHAR(100) NOT NULL,
    AvatarUrl       VARCHAR(500),
    Bio             TEXT,
    SkillLevel      DECIMAL(2,1) DEFAULT 3.0,  -- 1.0 - 5.0
    DominantHand    VARCHAR(10),                -- 'left', 'right'
    PaddleType      VARCHAR(100),
    CreatedAt       TIMESTAMP DEFAULT NOW(),
    UpdatedAt       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE RefreshTokens (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    UserId          INTEGER NOT NULL REFERENCES Users(Id) ON DELETE CASCADE,
    Token           VARCHAR(500) NOT NULL,
    ExpiresAt       TIMESTAMP NOT NULL,
    CreatedAt       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Follows (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    FollowerId      INTEGER NOT NULL REFERENCES Users(Id) ON DELETE CASCADE,
    FollowingId     INTEGER NOT NULL REFERENCES Users(Id) ON DELETE CASCADE,
    CreatedAt       TIMESTAMP DEFAULT NOW(),
    UNIQUE(FollowerId, FollowingId)
);

-- =============================================
-- GIẢI ĐẤU (TOURNAMENT): Quản lý giải đấu
-- =============================================

CREATE TABLE Tournaments (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CreatorId       INTEGER NOT NULL REFERENCES Users(Id),
    Name            VARCHAR(200) NOT NULL,
    Description     TEXT,
    Type            VARCHAR(10) NOT NULL CHECK (Type IN ('singles', 'doubles')),
    NumGroups       INTEGER NOT NULL,           -- đơn: 1-4, đôi: 1-2
    ScoringFormat   VARCHAR(15) DEFAULT 'best_of_3' CHECK (ScoringFormat IN ('best_of_1', 'best_of_3')),
    Status          VARCHAR(15) DEFAULT 'draft' CHECK (Status IN ('draft','open','ready','in_progress','completed','cancelled')),
    Date            DATE,
    Location        VARCHAR(500),
    BannerUrl       VARCHAR(500),
    CreatedAt       TIMESTAMP DEFAULT NOW(),
    UpdatedAt       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Participants (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TournamentId    INTEGER NOT NULL REFERENCES Tournaments(Id) ON DELETE CASCADE,
    UserId          INTEGER NOT NULL REFERENCES Users(Id),
    Status          VARCHAR(20) DEFAULT 'request_pending'
                    CHECK (Status IN ('confirmed','invited_pending','request_pending','rejected')),
    JoinedAt        TIMESTAMP,
    UNIQUE(TournamentId, UserId)
);

CREATE TABLE Teams (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TournamentId    INTEGER NOT NULL REFERENCES Tournaments(Id) ON DELETE CASCADE,
    Name            VARCHAR(100),
    Player1Id       INTEGER NOT NULL REFERENCES Users(Id),
    Player2Id       INTEGER NOT NULL REFERENCES Users(Id)
);

CREATE TABLE Groups (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TournamentId    INTEGER NOT NULL REFERENCES Tournaments(Id) ON DELETE CASCADE,
    Name            VARCHAR(10) NOT NULL,       -- 'A', 'B', 'C', 'D'
    DisplayOrder    INTEGER NOT NULL
);

CREATE TABLE GroupMembers (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    GroupId         INTEGER NOT NULL REFERENCES Groups(Id) ON DELETE CASCADE,
    PlayerId        INTEGER REFERENCES Users(Id),  -- NULL nếu là đấu đôi
    TeamId          INTEGER REFERENCES Teams(Id),  -- NULL nếu là đấu đơn
    SeedOrder       INTEGER
);

CREATE TABLE Matches (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TournamentId    INTEGER NOT NULL REFERENCES Tournaments(Id) ON DELETE CASCADE,
    GroupId         INTEGER REFERENCES Groups(Id),
    Round           INTEGER NOT NULL,           -- 1, 2, 3
    MatchOrder      INTEGER NOT NULL,           -- 1, 2 (trong mỗi vòng)
    Player1Id       INTEGER NOT NULL,           -- user_id (đơn) hoặc team_id (đôi)
    Player2Id       INTEGER NOT NULL,
    Player1Scores   JSONB,                      -- [11, 9, 11]
    Player2Scores   JSONB,                      -- [7, 11, 8]
    WinnerId        INTEGER,
    Status          VARCHAR(15) DEFAULT 'scheduled'
                    CHECK (Status IN ('scheduled','in_progress','completed','walkover')),
    CreatedAt       TIMESTAMP DEFAULT NOW(),
    UpdatedAt       TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- CỘNG ĐỒNG (COMMUNITY): Game cộng đồng (Giai đoạn 2)
-- =============================================

CREATE TABLE CommunityGames (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CreatorId       INTEGER NOT NULL REFERENCES Users(Id),
    Title           VARCHAR(200) NOT NULL,
    Description     TEXT,
    Date            TIMESTAMP NOT NULL,
    Location        VARCHAR(500),
    Latitude        DECIMAL(10, 8),
    Longitude       DECIMAL(11, 8),
    MaxPlayers      INTEGER NOT NULL,
    SkillLevel      VARCHAR(20),                -- 'beginner', 'intermediate', 'advanced', 'all'
    Status          VARCHAR(15) DEFAULT 'open'
                    CHECK (Status IN ('open','full','in_progress','completed','cancelled')),
    CreatedAt       TIMESTAMP DEFAULT NOW(),
    UpdatedAt       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE GameParticipants (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    GameId          INTEGER NOT NULL REFERENCES CommunityGames(Id) ON DELETE CASCADE,
    UserId          INTEGER NOT NULL REFERENCES Users(Id),
    Status          VARCHAR(15) DEFAULT 'confirmed'
                    CHECK (Status IN ('confirmed','waitlist','invited_pending','cancelled')),
    JoinedAt        TIMESTAMP DEFAULT NOW(),
    UNIQUE(GameId, UserId)
);

-- =============================================
-- CHAT: Tin nhắn (Giai đoạn 2)
-- =============================================

CREATE TABLE ChatRooms (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Type            VARCHAR(10) NOT NULL CHECK (Type IN ('direct', 'group')),
    Name            VARCHAR(100),               -- NULL cho chat trực tiếp (direct chat)
    CreatedAt       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ChatMembers (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    RoomId          INTEGER NOT NULL REFERENCES ChatRooms(Id) ON DELETE CASCADE,
    UserId          INTEGER NOT NULL REFERENCES Users(Id),
    JoinedAt        TIMESTAMP DEFAULT NOW(),
    MutedUntil      TIMESTAMP,
    UNIQUE(RoomId, UserId)
);

CREATE TABLE Messages (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    RoomId          INTEGER NOT NULL REFERENCES ChatRooms(Id) ON DELETE CASCADE,
    SenderId        INTEGER NOT NULL REFERENCES Users(Id),
    Content         TEXT NOT NULL,
    Type            VARCHAR(10) DEFAULT 'text' CHECK (Type IN ('text', 'image', 'system')),
    ReadBy          JSONB DEFAULT '[]',         -- [user_id, ...]
    CreatedAt       TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- THÔNG BÁO (NOTIFICATION)
-- =============================================

CREATE TABLE Notifications (
    Id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    UserId          INTEGER NOT NULL REFERENCES Users(Id) ON DELETE CASCADE,
    Type            VARCHAR(30) NOT NULL,       -- 'tournament_invite', 'request_approved', 'match_result', ...
    Title           VARCHAR(200) NOT NULL,
    Body            TEXT,
    Data            JSONB,                      -- {tournamentId, matchId, ...}
    IsRead          BOOLEAN DEFAULT FALSE,
    CreatedAt       TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- CHỈ MỤC (INDEXES)
-- =============================================

CREATE INDEX idx_participants_tournament ON Participants(TournamentId);
CREATE INDEX idx_participants_user ON Participants(UserId);
CREATE INDEX idx_matches_tournament ON Matches(TournamentId);
CREATE INDEX idx_matches_group ON Matches(GroupId);
CREATE INDEX idx_community_games_date ON CommunityGames(Date);
CREATE INDEX idx_community_games_location ON CommunityGames(Latitude, Longitude);
CREATE INDEX idx_messages_room ON Messages(RoomId, CreatedAt DESC);
CREATE INDEX idx_notifications_user ON Notifications(UserId, IsRead, CreatedAt DESC);
CREATE INDEX idx_follows_follower ON Follows(FollowerId);
CREATE INDEX idx_follows_following ON Follows(FollowingId);
```

---

## 5. Tổng Hợp Các Điểm Cuối API (API Endpoints)

### 5.1. Xác thực & Hồ sơ (Auth & Profile)

| Phương thức | Điểm cuối | Mô tả | Quyền |
|--------|----------|-------|-------|
| POST | /api/auth/register | Đăng ký | Công khai |
| POST | /api/auth/login | Đăng nhập | Công khai |
| POST | /api/auth/social | Đăng nhập OAuth2 (Google, Apple) | Công khai |
| POST | /api/auth/refresh | Làm mới token | Công khai |
| PUT | /api/auth/password | Đổi mật khẩu | Đã xác thực |
| GET | /api/users/me | Xem hồ sơ cá nhân | Đã xác thực |
| PUT | /api/users/me | Sửa hồ sơ cá nhân | Đã xác thực |
| GET | /api/users/me/tournaments | Lịch sử giải đấu đã tham gia | Đã xác thực |
| GET | /api/users/me/following | Danh sách đang theo dõi | Đã xác thực |
| GET | /api/users/me/followers | Danh sách người theo dõi | Đã xác thực |
| POST | /api/users/:id/follow | Theo dõi người dùng | Đã xác thực |
| DELETE | /api/users/:id/follow | Bỏ theo dõi người dùng | Đã xác thực |
| GET | /api/users/:id/profile | Xem hồ sơ người khác | Đã xác thực |
| GET | /api/users/:id/matches | Lịch sử trận đấu người khác | Đã xác thực |

### 5.2. Quản lý Giải đấu (Tournament Management)

| Phương thức | Điểm cuối | Mô tả | Quyền |
|--------|----------|-------|-------|
| GET | /api/tournaments | Danh sách giải đấu | Đã xác thực |
| POST | /api/tournaments | Tạo giải đấu mới | Đã xác thực |
| GET | /api/tournaments/:id | Chi tiết giải đấu | Đã xác thực |
| PUT | /api/tournaments/:id | Chỉnh sửa giải đấu | Người tạo |
| DELETE | /api/tournaments/:id | Hủy giải đấu | Người tạo |
| PUT | /api/tournaments/:id/status | Chuyển đổi trạng thái giải | Người tạo |
| POST | /api/tournaments/:id/invite | Mời người chơi | Người tạo |
| POST | /api/tournaments/:id/request | Xin tham gia giải | Đã xác thực |
| PUT | /api/tournaments/:id/requests/:rid | Duyệt/Từ chối yêu cầu | Người tạo |
| GET | /api/tournaments/:id/participants | Danh sách người tham gia | Đã xác thực |
| DELETE | /api/tournaments/:id/participants/:uid | Rời giải / Xóa người chơi | Tùy vai trò |
| POST | /api/tournaments/:id/teams | Ghép đôi thủ công (đấu đôi) | Người tạo |
| POST | /api/tournaments/:id/teams/random | Ghép đôi ngẫu nhiên | Người tạo |
| PUT | /api/tournaments/:id/teams | Chỉnh sửa đội | Người tạo |
| POST | /api/tournaments/:id/groups | Xếp bảng thủ công | Người tạo |
| POST | /api/tournaments/:id/groups/random | Xếp bảng ngẫu nhiên | Người tạo |

### 5.3. Trận đấu & Ghi điểm (Match & Scoring)

| Phương thức | Điểm cuối | Mô tả | Quyền |
|--------|----------|-------|-------|
| GET | /api/tournaments/:id/matches | Lịch thi đấu | Đã xác thực |
| GET | /api/tournaments/:id/draw | Dữ liệu sơ đồ thi đấu | Đã xác thực |
| POST | /api/matches/:id/score | Nhập điểm trận đấu | Người tạo |
| PUT | /api/matches/:id/score | Chỉnh sửa điểm số | Người tạo |
| GET | /api/tournaments/:id/groups/:gid/standings | Bảng xếp hạng bảng | Đã xác thực |
| GET | /api/tournaments/:id/results | Kết quả tổng kết giải | Đã xác thực |

### 5.4. Cộng đồng (Community) — Giai đoạn 2

| Phương thức | Điểm cuối | Mô tả | Quyền |
|--------|----------|-------|-------|
| GET | /api/community/lobby | Danh sách game giao hữu | Đã xác thực |
| POST | /api/community/games | Tạo game mới | Đã xác thực |
| GET | /api/community/games/:id | Chi tiết game | Đã xác thực |
| PUT | /api/community/games/:id | Chỉnh sửa game | Người tạo game |
| DELETE | /api/community/games/:id | Xóa game | Người tạo game |
| POST | /api/community/games/:id/invite | Mời người chơi | Người tạo game |
| POST | /api/community/games/:id/join | Tham gia game | Đã xác thực |
| DELETE | /api/community/games/:id/leave | Rời khỏi game | Đã xác thực |

### 5.5. Chat — Giai đoạn 2

| Phương thức | Điểm cuối | Mô tả | Quyền |
|--------|----------|-------|-------|
| GET | /api/chats | Danh sách các cuộc hội thoại | Đã xác thực |
| POST | /api/chats | Tạo phòng chat mới | Đã xác thực |
| GET | /api/chats/:id/messages | Danh sách tin nhắn | Thành viên |
| POST | /api/chats/:id/messages | Gửi tin nhắn mới | Thành viên |

### 5.6. Thông báo (Notification)

| Phương thức | Điểm cuối | Mô tả | Quyền |
|--------|----------|-------|-------|
| GET | /api/notifications | Danh sách thông báo | Đã xác thực |
| PUT | /api/notifications/:id/read | Đánh dấu đã đọc | Đã xác thực |
| PUT | /api/notifications/read-all | Đánh dấu đọc tất cả | Đã xác thực |

---

## 6. Realtime (SignalR Hubs)

### 6.1. TournamentHub

```
Hub: /hubs/tournament

Client → Server (Khách gửi):
  JoinTournament(tournamentId)       -- Đăng ký theo dõi giải
  LeaveTournament(tournamentId)      -- Ngừng theo dõi

Server → Client (Máy chủ gửi):
  ScoreUpdated(matchId, scores)      -- Cập nhật điểm số
  StandingsUpdated(groupId, standings) -- Cập nhật bảng xếp hạng
  MatchStatusChanged(matchId, status)  -- Thay đổi trạng thái trận đấu
  TournamentStatusChanged(status)      -- Thay đổi trạng thái giải đấu
```

### 6.2. ChatHub — Giai đoạn 2

```
Hub: /hubs/chat

Client → Server:
  SendMessage(roomId, content, type)
  TypingStart(roomId)
  TypingStop(roomId)
  MarkAsRead(roomId, messageId)

Server → Client:
  MessageReceived(message)
  UserTyping(roomId, userId)
  UserStoppedTyping(roomId, userId)
  MessageRead(roomId, userId, messageId)
```

### 6.3. NotificationHub

```
Hub: /hubs/notification

Server → Client:
  NewNotification(notification)      -- Có thông báo mới
  UnreadCountUpdated(count)          -- Cập nhật số lượng tin chưa đọc
```

---

## 7. Lộ Trình Triển Khai

### Giai đoạn 1: MVP — Cốt lõi Giải đấu (Tuần 1-8)

| Tuần | Nội dung | Mô-đun |
|------|----------|--------|
| 1-2 | Thiết lập dự án (.NET 8 + React + DB), Xác thực (đăng ký, đăng nhập, JWT) | M1 |
| 3-4 | Tạo/Sửa/Hủy giải, quản lý trạng thái, CRUD người tham gia | M2 |
| 5-6 | Ghép đôi, xếp bảng, tạo lịch Round Robin, hiển thị sơ đồ thi đấu | M2 + M4 |
| 7-8 | Nhập điểm, BXH, kết quả, tỉ số trực tiếp (SignalR), thông báo | M3 + M7 |

**Kết quả Giai đoạn 1:** Có thể tạo và vận hành một giải đấu vòng tròn (Round Robin) hoàn chỉnh.

### Giai đoạn 2: Mạng xã hội & Cộng đồng (Tuần 9-14)

| Tuần | Nội dung | Mô-đun |
|------|----------|--------|
| 9-10 | Hồ sơ nâng cao, hệ thống theo dõi, xem hồ sơ người khác | M1 |
| 11-12 | Game cộng đồng: tạo, tham gia, sảnh chờ, bản đồ | M5 |
| 13-14 | Chat thời gian thực (SignalR), thông báo đẩy (FCM) | M6 |

### Giai đoạn 3: Nâng cao (Tuần 15+)

- Thêm thể thức thi đấu: Loại trực tiếp (Single Elimination), Loại kép (Double Elimination), Vòng bảng + Vòng loại trực tiếp
- Thanh toán trực tuyến (VNPay/Momo) cho các giải đấu có phí
- Check-in tại sân bằng mã QR
- Hệ thống xếp hạng (Dựa trên ELO, tự động tính toán sau mỗi trận)
- Trang quản trị (Dashboard) phân tích cho nhà tổ chức
- Tích hợp Livestream
- Chia sẻ kết quả lên mạng xã hội (Tự động tạo thẻ hình ảnh kết quả)

---

## 8. Ghi Chú Kỹ Thuật Quan Trọng

### 8.1. Bảo mật

- **JWT access token:** Có thời hạn 15 phút, **refresh token:** Có thời hạn 7 ngày.
- **Băm mật khẩu (Password hash):** Sử dụng thuật toán bcrypt (với cost factor là 12).
- **Giới hạn tốc độ (Rate limit):** Đăng nhập tối đa 5 lần/15 phút, các API chung tối đa 100 yêu cầu/phút.
- **Cấu hình CORS:** Cần cấu hình chính xác cho cả nền tảng web và ứng dụng di động.
- **Kiểm tra dữ liệu đầu vào (Input validation):** Thực hiện ở cả phía người dùng (Frontend) và máy chủ (Backend).

### 8.2. Hiệu suất (Performance)

- **Bộ nhớ đệm (Redis cache):** Lưu trữ dữ liệu bảng điều khiển, các bảng xếp hạng và danh sách giải đấu.
- **Chỉ mục cơ sở dữ liệu (Database indexing):** Thiết lập cho các câu lệnh truy vấn thường xuyên (xem chi tiết tại Mục 4.2).
- **Phân trang (Pagination):** Sử dụng dạng con trỏ (cursor-based) cho các nguồn cấp dữ liệu hoặc chat, và dạng bù (offset-based) cho các danh sách thông thường.
- **Hình ảnh:** Thay đổi kích thước và nén trước khi tải lên (ảnh đại diện: 256x256, ảnh bìa: 1200x630).
- **Tính toán lại bảng xếp hạng:** Chạy bất đồng bộ thông qua các tác vụ chạy nền (background job).

### 8.3. Khả năng mở rộng (Scalability)

- **Stateless API (.NET):** Giúp dễ dàng mở rộng theo chiều ngang (horizontal scale).
- **SignalR với Redis backplane:** Hỗ trợ hoạt động đa luồng/đa máy chủ (multi-instance).
- **Tác vụ chạy nền (Background jobs):** Sử dụng .NET Background Service cho các tác vụ đơn giản hoặc RabbitMQ cho các quy trình phức tạp hơn.
- **Lưu trữ tệp tin:** Sử dụng Cloudinary (gói miễn phí), tuyệt đối không lưu trữ trên máy chủ cục bộ.

### 8.4. Giám sát (Monitoring)

- **Ghi nhật ký cấu trúc (Structured logging):** Sử dụng Serilog.
- **Điểm cuối kiểm tra sức khỏe (Health checks endpoint):** Để theo dõi trạng thái hệ thống.
- **Theo dõi lỗi (Error tracking):** Sử dụng Sentry.
- **Số liệu API (API metrics):** Theo dõi thời gian phản hồi và tỷ lệ lỗi.
