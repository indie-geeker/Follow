# Follow 家庭音乐 - Backend

基于 .NET 10 的家庭音乐库后端：负责家庭成员认证、音乐编目、流式播放、收藏、历史和个人歌单。

## 技术栈

- **框架**: ASP.NET Core 10 Minimal API
- **数据库**: PostgreSQL 18 + EF Core
- **缓存**: Redis 8
- **对象存储**: MinIO
- **认证**: JWT + 按设备隔离的 Refresh Session；Web 使用 HttpOnly Cookie，App 使用系统安全存储
- **元数据**: TagLibSharp

## 快速开始

### 1. 配置并启动完整 Docker 服务

```bash
cd ..
cp .env.example .env  # 首次运行；请替换所有占位值
docker compose up -d --build
```

本地 Compose 将 API 绑定到 `http://127.0.0.1:5050`，管理后台绑定到 `http://127.0.0.1:3000`。Android Emulator 通过 `http://10.0.2.2:5050` 直连 API；无需本地 HTTPS 网关或证书。

- 管理后台：容器 Nginx 将同源 `/api/*` 代理到内部 API
- API：仅发布到宿主机 loopback `5050`，用于本地 Flutter 与诊断
- PostgreSQL、Redis：不发布宿主机端口；通过 `docker compose exec` 维护
- MinIO：只在 Docker 内网开放，不发布 API 或控制台端口

API 容器启动时会自动执行数据库迁移，并根据根目录 `.env` 中的 `ADMIN_USERNAME`、`ADMIN_EMAIL`、`ADMIN_PASSWORD` 创建或维护管理员账号。Docker 使用 Production 环境，不开放 Swagger。

## API 模块

| 模块 | 路径 | 描述 |
|------|------|------|
| 认证 | `/api/auth` | 登录/注册/刷新、设备会话与注销 |
| 曲目 | `/api/tracks` | 音乐上传、Range 播放、封面和歌词管理 |
| 艺术家 | `/api/artists` | 艺术家管理 |
| 专辑 | `/api/albums` | 专辑管理 |
| 播放列表 | `/api/playlists` | 私有/公开歌单、所有权与排序 |
| 用户功能 | `/api/user` | 收藏/播放历史 |
| 管理员 | `/api/admin` | 用户管理/仪表盘 |

## 用户角色

- **Admin**: 可上传/删除音乐、管理用户、管理艺术家/专辑
- **Member**: 可播放音乐、收藏曲目、创建个人播放列表

> 管理员由环境变量维护；所有公开注册用户均为 Member。管理员可在网页后台创建 Member 或 Admin 账号。

## 核心契约

### 认证与设备会话

- 每次登录创建独立 `UserSession`，数据库只保存 Refresh Token 哈希；刷新时轮换令牌，Access Token 携带 `sid` 并在每次认证时校验会话仍有效。
- Web 传 `tokenTransport: "cookie"`，服务端只设置同源 `Secure`、`HttpOnly`、`SameSite=Strict` Cookie，JSON 不返回令牌；Flutter 使用默认 `body` 模式，并把令牌写入平台安全存储。
- `POST /api/auth/logout` 立即撤销当前会话；`POST /api/auth/logout-all` 撤销该用户全部设备；`GET /api/auth/sessions` 与 `DELETE /api/auth/sessions/{id}` 用于查看和撤销指定设备。用户不能操作其他用户的会话。
- 注册、登录、刷新、普通 API、上传和播放分别限流；超过限制返回 `429`，并携带 `Retry-After`。

### 媒体与对象存储

- `GET`/`HEAD /api/tracks/{id}/stream` 直接从对象存储复制到响应体，支持单段 `Range`；完整、分段和越界请求分别返回 `200`、`206`、`416`，不会先把整首音乐读入内存。
- MinIO 只在 Docker 内网开放。客户端只能通过同源 API 访问媒体；匿名封面代理只接受受管的图片前缀和扩展名，不能读取音频、歌词或任意对象路径。
- 数据库写入与对象生命周期按补偿/事务处理：上传失败会清理新对象；替换或删除元数据时，在同一数据库事务写入 `StorageDeletionJob`，后台 worker 重试删除旧对象，避免数据库与对象存储永久失配。

### 所有权与分页

- 私有歌单仅所有者可读；公开歌单可被其他家庭成员只读查看。更新、删除、增删曲目和重排始终要求所有者身份。
- 重排请求必须提交当前歌单曲目的完整、无重复排列，服务端原子更新位置，不接受缺项、重复或外来曲目。
- 带分页参数的列表接口校验 `page >= 1`、`pageSize`/`limit` 的上限，并使用稳定的次级 ID 排序；响应中的页码、总数和总页数基于同一筛选条件。

## 项目结构

```
follow-server/
├── docker-compose.yml       # 开发环境
├── src/
│   ├── Follow.Api/          # API 入口
│   ├── Follow.Core/         # 实体和接口
│   ├── Follow.Infrastructure/  # 数据库和服务
│   └── Follow.Shared/       # DTO 和常量
└── tests/
    ├── Follow.Api.Tests/
    └── Follow.Core.Tests/
```

## 配置

服务端基础配置位于 `src/Follow.Api/appsettings*.json`，完整 Docker 栈的密码和站点地址从仓库根目录 `.env` 注入。不要把真实凭据写入版本库或前端构建参数。

### 关键配置项

| 配置项 | 说明 |
|--------|------|
| `ConnectionStrings.DefaultConnection` | PostgreSQL 数据库连接字符串 |
| `JwtSettings.SecretKey` | JWT 签名密钥，**至少 32 字符** |
| `JwtSettings.AccessTokenExpirationMinutes` | Access Token 过期时间(分钟) |
| `JwtSettings.RefreshTokenExpirationDays` | Refresh Token 过期时间(天) |
| `MinioSettings.Endpoint` | MinIO 服务地址 |
| `MinioSettings.UseSSL` | API 到 MinIO 的内部连接是否使用 TLS；这不会把 MinIO 暴露给客户端 |
| `RedisSettings.ConnectionString` | Redis 连接字符串 |
| `RateLimiting.*` | 注册、登录、刷新、普通 API、上传和并发播放的限制 |
| `ForwardedHeaders.KnownProxies` / `KnownNetworks` | 上线时由运维显式配置的可信 HTTPS 反向代理地址或网络；本地 Compose 不默认信任转发头 |

## MinIO 存储位置

### 本地开发环境 (Docker)

MinIO 数据保存在 Compose 管理的 `minio_data` 命名卷中。不要直接修改 Docker 虚拟机中的卷文件；备份和恢复应使用 MinIO/S3 工具，并与 PostgreSQL 备份保持同一时间点。

### 生产服务器

推荐将 MinIO 数据挂载到主机目录:

```yaml
# docker-compose.prod.yml
services:
  minio:
    volumes:
      - /data/minio:/data  # 挂载到主机 /data/minio 目录
```

服务器存储路径: `/data/minio`

MinIO 不发布主机端口或控制台。维护操作应通过 Docker 内网、容器命令或临时且受控的端口转发完成，不能把对象存储地址发给 Web/App 客户端。

## 目录批量导入（显式启用）

服务端目录导入默认关闭，基础 `docker-compose.yml` 不挂载任何音乐源目录。只有部署者在仓库根目录被 Git 忽略的 `.env` 中设置一个已经存在的绝对路径，并显式叠加 `docker-compose.import.yml` 时，API 内的导入 worker 才能读取该目录：

```dotenv
FOLLOW_IMPORT_SOURCE_PATH=/srv/music-library
```

该路径会以长语法只读绑定到 API 容器的 `/imports/library`，并设置 `bind.create_host_path: false`；路径不存在时 Compose 会失败，不会创建空目录。它是待扫描的源音乐库，不是 MinIO 的 `/data` 对象存储目录，也不能指向 `minio_data` 卷。

部署者确认路径、备份和容量后，可在未来的人工验证窗口执行以下命令；自动化验证只运行 `config`，不会启动容器：

```bash
# 先检查变量插值、只读 bind 和合并后的完整配置
docker compose -f docker-compose.yml -f docker-compose.import.yml config --quiet

# 人工确认无误后，再显式启动带导入能力的完整栈
docker compose -f docker-compose.yml -f docker-compose.import.yml up -d --build
```

源目录始终只读，导入流程不会修改或删除源文件。取消批次只停止尚未开始的工作，已经成功导入的 Track 会保留，不会自动回滚。完成后，在移除 overlay 或挂载前必须再次扫描同一目录，确认导入具备幂等性且不会生成重复曲目；未通过该检查时应保留挂载并排查失败项。

## 嵌入媒体元数据回填（仅管理员手工执行）

服务端不会在启动时自动回填历史曲目。需要补齐嵌入封面或带时间戳歌词时，按以下顺序操作：

1. 先以管理员身份调用 `POST /api/admin/tracks/metadata-backfill`，请求体使用 `{"dryRun":true,"afterId":null,"limit":50}`。
2. 检查返回的候选数、支持的封面/歌词数、失败数和逐曲目错误码；响应不会返回封面字节或歌词正文。
3. 取得明确的数据变更授权后，才把 `dryRun` 改为 `false`，一次只执行一个不超过 100 条的有界页面。
4. 使用响应中的 `nextAfterId` 继续下一页；不要并行执行同一区间。
5. 每页完成后核对数据库 `CoverUrl`/`LyricsUrl`，并通过 API 封面和歌词路由验证对象可读。

回填只会填写值为 `null` 的引用。管理员已经设置的引用和执行期间发生的并发更新优先，新建但未被引用的对象会立即补偿删除或进入删除队列。

## 开发与部署

### 开发环境

```bash
# 1. 从仓库根目录启动依赖服务
cd ..
docker compose up -d postgres redis minio

# 返回后端目录
cd follow-server

# 2. 迁移数据库
dotnet ef database update --project src/Follow.Infrastructure --startup-project src/Follow.Api

# 3. 运行 API（自动使用 Development 配置）
cd src/Follow.Api
dotnet run
```

访问: http://localhost:5050/swagger

### 生产环境打包

```bash
# 发布到 publish 目录
dotnet publish src/Follow.Api -c Release -o ./publish
```

### 生产环境运行

仓库根目录 Compose 面向本机运行，API 和管理后台仅绑定 loopback。上线时在 `127.0.0.1:3000` 前配置独立的 HTTPS 反向代理，使用真实域名和公共可信证书；不得直接向公网发布 `3000`、`5050` 或 MinIO。升级前同时备份 PostgreSQL 与对象存储，检查迁移后再替换运行中的容器。

### 环境变量覆盖配置

生产环境可通过环境变量覆盖配置（推荐用于敏感信息）：

```bash
# 数据库连接
export ConnectionStrings__DefaultConnection="Host=prod-db;..."

# JWT 密钥
export JwtSettings__SecretKey="your-production-secret-key"

# 启动时维护的管理员账号
export AdminAccount__Username="admin"
export AdminAccount__Email="admin@example.com"
export AdminAccount__Password="your-strong-admin-password"
```

> **提示**: .NET 会自动根据 `ASPNETCORE_ENVIRONMENT` 环境变量加载对应的配置文件。

## 用户注册

### 通过 API 注册

```bash
# 通过生产 HTTPS origin 注册新用户
curl -X POST https://music.home.example/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "your_username",
    "email": "your_email@example.com",
    "password": "StrongPassword!2026"
  }'
```

### 通过 Swagger 注册

1. 访问 http://localhost:5050/swagger（仅 Development 环境）
2. 找到 `POST /api/auth/register` 接口
3. 点击 "Try it out"
4. 填写注册信息并执行

> **注意**: 公开注册账号固定为 Member。用户名会执行 NFKC、去首尾空白和小写规范化；密码必须为 6-128 位，且同时包含大小写字母、数字和特殊字符，不能包含空白字符。

## 管理员账号与邀请用户

- `.env` 中的管理员账号在 API 启动、数据库迁移完成后创建或更新。
- `ADMIN_PASSWORD` 是该账号密码的权威来源；修改后重启 API 会覆盖数据库中的管理员密码。
- 管理员通过与 API 同源的 HTTPS 地址登录，进入“用户管理”，点击“邀请用户”可创建 Member 或 Admin。
- 当前项目未集成邮件服务，后台会生成临时密码，需要管理员通过安全渠道交付给用户。
