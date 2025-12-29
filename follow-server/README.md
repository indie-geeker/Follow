# Follow Music Player - Backend

基于 .NET 10 的跨平台音乐播放器后端服务。

## 技术栈

- **框架**: ASP.NET Core 10 Minimal API
- **数据库**: PostgreSQL 18 + EF Core
- **缓存**: Redis 8
- **对象存储**: MinIO
- **认证**: JWT + Refresh Token
- **元数据**: TagLibSharp

## 快速开始

### 1. 启动 Docker 服务

```bash
docker compose up -d
```

服务:
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- MinIO: localhost:9000 (控制台: localhost:9001)

### 2. 数据库迁移

```bash
# 首次安装 EF Core 工具
dotnet tool install --global dotnet-ef

# 执行迁移
dotnet ef database update --project src/Follow.Infrastructure --startup-project src/Follow.Api
```

### 3. 运行 API

```bash
dotnet run --project src/Follow.Api
```

访问 http://localhost:5000/swagger

## API 模块

| 模块 | 路径 | 描述 |
|------|------|------|
| 认证 | `/api/auth` | 登录/注册/刷新Token |
| 曲目 | `/api/tracks` | 音乐上传/播放/封面/歌词管理 |
| 艺术家 | `/api/artists` | 艺术家管理 |
| 专辑 | `/api/albums` | 专辑管理 |
| 播放列表 | `/api/playlists` | 用户播放列表 |
| 用户功能 | `/api/user` | 收藏/播放历史 |
| 管理员 | `/api/admin` | 用户管理/仪表盘 |
| RSS | `/api/rss` | 播客订阅 |

## 用户角色

- **Admin**: 可上传/删除音乐、管理用户、管理艺术家/专辑
- **Member**: 可播放音乐、收藏曲目、创建个人播放列表

> 首个注册的用户自动成为 Admin

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

## 配置文件

### 配置文件列表

| 文件 | 用途 | 是否提交到 Git |
|------|------|----------------|
| `appsettings.json` | 基础配置，所有环境共用 | ✅ 是 |
| `appsettings.Development.json` | 开发环境配置 | ✅ 是 |
| `appsettings.Production.json` | 生产环境配置 | ❌ 否 (需手动创建) |

配置文件位于: `src/Follow.Api/`

### 开发环境配置 (appsettings.Development.json)

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information",
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=follow;Username=follow;Password=follow"
  },
  "JwtSettings": {
    "SecretKey": "DevelopmentSecretKey_MustBeAtLeast32CharactersLong!!",
    "Issuer": "FollowMusicApi",
    "Audience": "FollowMusicClient",
    "AccessTokenExpirationMinutes": 60,
    "RefreshTokenExpirationDays": 7
  },
  "MinioSettings": {
    "Endpoint": "localhost:9000",
    "AccessKey": "follow",
    "SecretKey": "follow123",
    "BucketName": "follow-music",
    "UseSSL": false
  },
  "RedisSettings": {
    "ConnectionString": "localhost:6379"
  }
}
```

### 生产环境配置 (appsettings.Production.json)

需要手动创建此文件，**不要提交到 Git**：

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=your-db-host;Port=5432;Database=follow;Username=prod_user;Password=强密码"
  },
  "JwtSettings": {
    "SecretKey": "生产环境专用密钥_至少32个字符_随机生成",
    "Issuer": "FollowMusicApi",
    "Audience": "FollowMusicClient",
    "AccessTokenExpirationMinutes": 30,
    "RefreshTokenExpirationDays": 7
  },
  "MinioSettings": {
    "Endpoint": "your-minio-host:9000",
    "AccessKey": "生产AccessKey",
    "SecretKey": "生产SecretKey",
    "BucketName": "follow-music",
    "UseSSL": true
  },
  "RedisSettings": {
    "ConnectionString": "your-redis-host:6379"
  }
}
```

### 配置项说明

| 配置项 | 说明 |
|--------|------|
| `ConnectionStrings.DefaultConnection` | PostgreSQL 数据库连接字符串 |
| `JwtSettings.SecretKey` | JWT 签名密钥，**至少 32 字符** |
| `JwtSettings.AccessTokenExpirationMinutes` | Access Token 过期时间(分钟) |
| `JwtSettings.RefreshTokenExpirationDays` | Refresh Token 过期时间(天) |
| `MinioSettings.Endpoint` | MinIO 服务地址 |
| `MinioSettings.UseSSL` | 是否使用 HTTPS |
| `RedisSettings.ConnectionString` | Redis 连接字符串 |

## MinIO 存储位置

### 本地开发环境 (Docker)

MinIO 数据存储在 Docker 卷中:

```bash
# 查看卷位置
docker volume inspect follow-server_minio_data
```

实际存储路径 (macOS/Linux):
- **Docker Desktop**: `~/Library/Containers/com.docker.docker/Data/vms/0/data/docker/volumes/follow-server_minio_data/_data`
- **Linux**: `/var/lib/docker/volumes/follow-server_minio_data/_data`

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

### 访问 MinIO 控制台

- **本地**: http://localhost:9001
- **用户名**: follow
- **密码**: follow123

## 开发与部署

### 开发环境

```bash
# 1. 启动依赖服务
docker compose up -d

# 2. 迁移数据库
dotnet ef database update --project src/Follow.Infrastructure --startup-project src/Follow.Api

# 3. 运行 API（自动使用 Development 配置）
cd src/Follow.Api
dotnet run
```

访问: http://localhost:5000/swagger

### 生产环境打包

```bash
# 发布到 publish 目录
dotnet publish src/Follow.Api -c Release -o ./publish
```

### 生产环境运行

```bash
# 方式1: 直接运行
cd publish
ASPNETCORE_ENVIRONMENT=Production ./Follow.Api

# 方式2: 使用 Docker
docker build -t follow-api .
docker run -d -p 5000:5000 \
  -e ASPNETCORE_ENVIRONMENT=Production \
  follow-api
```

### 环境变量覆盖配置

生产环境可通过环境变量覆盖配置（推荐用于敏感信息）：

```bash
# 数据库连接
export ConnectionStrings__DefaultConnection="Host=prod-db;..."

# JWT 密钥
export JwtSettings__SecretKey="your-production-secret-key"
```

> **提示**: .NET 会自动根据 `ASPNETCORE_ENVIRONMENT` 环境变量加载对应的配置文件。

## 用户注册

### 通过 API 注册

```bash
# 注册新用户
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "your_username",
    "email": "your_email@example.com",
    "password": "your_password"
  }'
```

### 通过 Swagger 注册

1. 访问 http://localhost:5000/swagger
2. 找到 `POST /api/auth/register` 接口
3. 点击 "Try it out"
4. 填写注册信息并执行

> **注意**: 首个注册的用户自动成为 Admin 角色，拥有完整管理权限。
