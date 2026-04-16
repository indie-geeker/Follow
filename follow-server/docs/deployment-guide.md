# Follow Music Player Backend - 部署指南

> 本文档提供从服务器环境准备到项目部署上线的完整操作指南

## 目录

- [环境要求](#环境要求)
- [服务器准备](#服务器准备)
- [软件安装](#软件安装)
- [端口配置](#端口配置)
- [项目构建与发布](#项目构建与发布)
- [生产环境配置](#生产环境配置)
- [部署方式](#部署方式)
- [反向代理配置](#反向代理配置)
- [运维与监控](#运维与监控)
- [常见问题](#常见问题)

---

## 环境要求

### 硬件配置 (最低要求)

| 配置项 | 最低配置 | 推荐配置 |
|--------|----------|----------|
| **CPU** | 1 核 | 2 核+ |
| **内存** | 2 GB | 4 GB+ |
| **硬盘** | 20 GB SSD | 根据音乐库大小而定 |
| **带宽** | 5 Mbps | 10 Mbps+ |

### 操作系统

支持以下 Linux 发行版:

- **Ubuntu** 20.04/22.04/24.04 LTS (推荐)
- **Debian** 11/12
- **CentOS** 8/9 / Rocky Linux 8/9
- **其他** 支持 Docker 的 Linux 发行版

---

## 服务器准备

### 1. 更新系统

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/Rocky Linux
sudo dnf update -y
```

### 2. 创建应用用户 (可选但推荐)

```bash
# 创建专用用户
sudo useradd -m -s /bin/bash follow
sudo usermod -aG docker follow

# 切换到应用用户
sudo su - follow
```

### 3. 创建目录结构

```bash
# 应用目录
sudo mkdir -p /opt/follow-server

# 设置权限
sudo chown -R follow:follow /opt/follow-server
```

---

## 软件安装

### 必需软件列表

| 软件 | 版本 | 用途 | 安装方式 |
|------|------|------|----------|
| **Docker** | 24.0+ | 容器运行时 | 必须安装 |
| **Docker Compose** | v2.20+ | 容器编排 | 必须安装 |
| **Git** | 2.30+ | 代码拉取 | 推荐安装 |
| **Nginx** | 1.18+ | 反向代理 (可选) | 推荐安装 |

### 安装 Docker

#### Ubuntu/Debian

```bash
# 移除旧版本
sudo apt remove docker docker-engine docker.io containerd runc

# 安装依赖
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker 仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动并设置开机启动
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到 docker 组（需重新登录生效）
sudo usermod -aG docker $USER
```

#### CentOS/Rocky Linux

```bash
# 安装依赖
sudo dnf install -y yum-utils

# 添加 Docker 仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装 Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动并设置开机启动
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER
```

### 验证 Docker 安装

```bash
docker --version
docker compose version
```

### 安装 Git

```bash
# Ubuntu/Debian
sudo apt install -y git

# CentOS/Rocky Linux
sudo dnf install -y git
```

### 安装 Nginx (可选，用于反向代理)

```bash
# Ubuntu/Debian
sudo apt install -y nginx

# CentOS/Rocky Linux
sudo dnf install -y nginx

# 启动并设置开机启动
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

## 端口配置

### 服务端口说明

| 服务 | 端口 | 方向 | 说明 |
|------|------|------|------|
| **Follow API** | 5000 | 入站 | 后端 API 服务 |
| **PostgreSQL** | 5432 | 内部 | 数据库 (不建议对外开放) |
| **Redis** | 6379 | 内部 | 缓存服务 (不建议对外开放) |
| **MinIO API** | 9000 | 内部 | 对象存储 API |
| **MinIO Console** | 9001 | 入站 | MinIO 管理控制台 |
| **HTTP** | 80 | 入站 | Nginx 反向代理 |
| **HTTPS** | 443 | 入站 | Nginx SSL |

### 防火墙配置

#### UFW (Ubuntu/Debian)

```bash
# 开启防火墙
sudo ufw enable

# 允许 SSH
sudo ufw allow ssh

# 允许 HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 允许 API 端口 (如果不使用反向代理)
sudo ufw allow 5000/tcp

# 允许 MinIO 控制台 (可选，仅管理员访问时开启)
# sudo ufw allow 9001/tcp

# 查看状态
sudo ufw status
```

#### Firewalld (CentOS/Rocky Linux)

```bash
# 启动防火墙
sudo systemctl start firewalld
sudo systemctl enable firewalld

# 允许 HTTP/HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 允许 API 端口
sudo firewall-cmd --permanent --add-port=5000/tcp

# 重新加载
sudo firewall-cmd --reload

# 查看状态
sudo firewall-cmd --list-all
```

> [!IMPORTANT]
> **安全建议**: PostgreSQL (5432) 和 Redis (6379) 端口不应对外网开放，仅允许内部容器网络通信。

---

## 项目构建与发布

> [!NOTE]
> 以下提供三种方式将项目部署到服务器。推荐使用**方式一**（服务器克隆源码）或**方式二**（Docker Hub），操作最简单。

### 方式一：在服务器上克隆源码构建 (推荐)

```bash
# 1. 克隆项目到服务器
cd /opt/follow-server
git clone https://github.com/your-repo/follow-server.git .

# 项目已包含 Dockerfile 和 docker-compose.yml，可以直接构建
# 转到 "生产环境配置" 章节继续
```

### 方式二：使用 Docker Hub (推荐用于 CI/CD)

```bash
# 本地构建并推送镜像
docker build -t your-dockerhub-username/follow-api:latest .
docker push your-dockerhub-username/follow-api:latest

# 服务器拉取镜像
docker pull your-dockerhub-username/follow-api:latest
```

使用此方式时，需修改 `docker-compose.yml` 中 `api` 服务的 `build: .` 为 `image: your-dockerhub-username/follow-api:latest`。

### 方式三：本地打包上传

在**开发机器**上执行:

```bash
# 1. 克隆或进入项目目录
git clone https://github.com/your-repo/follow-server.git
cd follow-server

# 2. 打包整个项目 (包含 Dockerfile 和 docker-compose.yml)
tar -czvf follow-server.tar.gz \
  --exclude='.git' \
  --exclude='bin' \
  --exclude='obj' \
  --exclude='publish' \
  .

# 3. 上传到服务器
scp follow-server.tar.gz user@your-server:/opt/follow-server/
```

在**服务器**上执行:

```bash
cd /opt/follow-server

# 解压
tar -xzvf follow-server.tar.gz

# 目录结构应包含:
# /opt/follow-server/
#   ├── Dockerfile
#   ├── docker-compose.yml
#   ├── src/
#   │   ├── Follow.Api/
#   │   ├── Follow.Core/
#   │   ├── Follow.Infrastructure/
#   │   └── Follow.Shared/
#   └── ...
```

> [!CAUTION]
> 必须打包完整的源码目录（包含 `Dockerfile`、`docker-compose.yml` 和 `src/`），而不是仅打包 `dotnet publish` 的输出。Docker 构建过程需要源码和 Dockerfile。

---

## 生产环境配置

### 1. 修改生产配置文件

编辑 `src/Follow.Api/appsettings.Production.json`，将占位符替换为实际密码:

```bash
cd /opt/follow-server
nano src/Follow.Api/appsettings.Production.json
```

内容示例:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Host=postgres;Port=5432;Database=follow;Username=follow;Password=你的强密码"
  },
  "JwtSettings": {
    "SecretKey": "生成至少32字符的随机字符串_用于生产环境JWT签名",
    "Issuer": "FollowMusicApi",
    "Audience": "FollowMusicClient",
    "AccessTokenExpirationMinutes": 30,
    "RefreshTokenExpirationDays": 7
  },
  "MinioSettings": {
    "Endpoint": "minio:9000",
    "AccessKey": "你的Minio访问密钥",
    "SecretKey": "你的Minio密钥",
    "BucketName": "follow-music",
    "UseSSL": false
  },
  "RedisSettings": {
    "ConnectionString": "redis:6379"
  }
}
```

> [!IMPORTANT]
> 配置中的 `postgres`、`minio`、`redis` 是 Docker Compose 中定义的服务名称，Docker 会自动通过内部 DNS 将其解析为对应容器的 IP。请勿改为 `localhost`。

> [!CAUTION]
> **安全提醒**:
> - `JwtSettings.SecretKey` 必须使用随机生成的强密码
> - `ConnectionStrings.DefaultConnection` 中的密码需与 `.env` 文件中 `POSTGRES_PASSWORD` 保持一致
> - 不要将生产配置文件提交到 Git

### 2. 生成随机密钥

```bash
# 生成 32 位随机字符串
openssl rand -base64 32
```

### 3. 创建环境变量文件

创建 `/opt/follow-server/.env` 用于存储敏感信息:

```bash
# PostgreSQL
POSTGRES_PASSWORD=你的数据库强密码

# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=你的MinIO强密码
```

> [!NOTE]
> 环境变量文件包含敏感信息，确保权限设置正确: `chmod 600 .env`

---

## 部署方式

### 方式一：Docker Compose 部署 (推荐)

```bash
cd /opt/follow-server

# 1. 构建并启动所有服务
docker compose up -d --build

# 2. 查看服务状态
docker compose ps

# 3. 查看 API 日志
docker compose logs -f api
```

项目的 `docker-compose.yml` 已包含完整的服务编排:
- **api**: 后端 API 服务 (通过 Dockerfile 构建)
- **postgres**: PostgreSQL 数据库
- **redis**: Redis 缓存
- **minio**: MinIO 对象存储

所有服务通过 `follow-network` 互联，API 服务监听 5000 端口，MinIO 控制台通过 9001 端口访问。

### 方式二：直接运行二进制文件

> [!WARNING]
> 此方式需要单独安装和管理 PostgreSQL、Redis、MinIO 等依赖服务，推荐使用 Docker Compose 方式。

需要先安装 .NET Runtime:

```bash
# Ubuntu
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install -y aspnetcore-runtime-10.0

# 构建项目
cd /opt/follow-server
dotnet publish src/Follow.Api -c Release -o ./publish

# 运行应用
cd publish
ASPNETCORE_ENVIRONMENT=Production ./Follow.Api
```

### 首次部署检查步骤

```bash
# 1. 确认所有容器运行正常
docker compose ps

# 2. 检查 API 健康状态
curl http://localhost:5000/health

# 3. 检查 MinIO 控制台是否可访问
curl http://localhost:9001

# 4. 查看日志排查问题
docker compose logs -f
```

### 数据库迁移

> [!TIP]
> 应用已配置**自动数据库迁移**，首次启动时会自动创建所有数据库表。无需手动执行迁移命令。

如果需要手动执行迁移 (例如在开发环境中)，可以使用:

```bash
# 需要在有源码和 .NET SDK 的环境中执行
cd /opt/follow-server
dotnet ef database update \
  --project src/Follow.Infrastructure \
  --startup-project src/Follow.Api
```

---

## 反向代理配置

### Nginx 配置示例

创建 `/etc/nginx/sites-available/follow`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 重定向到 HTTPS (可选)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 证书 (使用 Let's Encrypt 或其他)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 文件上传大小限制
        client_max_body_size 100M;
    }

    # 音频流代理 (增加缓冲)
    location /api/tracks {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_buffering off;
        proxy_cache off;

        client_max_body_size 500M;  # 音频文件上传限制
    }

    # Swagger 文档 (生产环境可禁用)
    location /swagger {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:5000;
    }
}
```

启用配置:

```bash
sudo ln -s /etc/nginx/sites-available/follow /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 申请 SSL 证书 (Let's Encrypt)

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 申请证书
sudo certbot --nginx -d your-domain.com

# 自动续期测试
sudo certbot renew --dry-run
```

---

## 运维与监控

### 常用运维命令

```bash
# 查看所有服务状态
docker compose ps

# 查看日志
docker compose logs -f api
docker compose logs -f postgres

# 重启服务
docker compose restart api

# 停止所有服务
docker compose down

# 更新代码并重新构建
git pull
docker compose up -d --build

# 进入容器调试
docker exec -it follow-api /bin/bash
docker exec -it follow-postgres psql -U follow
```

### 数据备份

#### 备份 PostgreSQL

```bash
# 创建备份脚本 /opt/follow-server/backup.sh
#!/bin/bash
BACKUP_DIR=/data/backups/postgres
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)
docker exec follow-postgres pg_dump -U follow follow > $BACKUP_DIR/follow_$DATE.sql
gzip $BACKUP_DIR/follow_$DATE.sql

# 保留最近 7 天的备份
find $BACKUP_DIR -mtime +7 -name "*.sql.gz" -delete
```

```bash
# 添加定时任务
chmod +x /opt/follow-server/backup.sh
crontab -e
# 添加: 0 2 * * * /opt/follow-server/backup.sh
```

### 监控建议

- **容器监控**: 使用 `docker stats` 或 Portainer
- **日志聚合**: ELK Stack 或 Loki + Grafana
- **应用监控**: 集成 Prometheus + Grafana
- **告警**: 配置 AlertManager 或云服务告警

### 设置 Systemd 服务 (可选)

创建 `/etc/systemd/system/follow-server.service`:

```ini
[Unit]
Description=Follow Music Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/follow-server
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

启用服务:

```bash
sudo systemctl daemon-reload
sudo systemctl enable follow-server
sudo systemctl start follow-server
```

---

## 常见问题

### 1. API 启动失败，连接数据库超时

**原因**: PostgreSQL 容器还未完全启动

**解决**: 
```bash
# 检查 PostgreSQL 状态
docker logs follow-postgres

# 等待完全启动后重启 API
docker compose restart api
```

### 2. MinIO 上传失败

**原因**: Bucket 未创建

**解决**: 应用已配置自动创建 Bucket。如果仍然失败:
```bash
# 访问 MinIO 控制台 http://your-server:9001
# 手动创建 bucket: follow-music

# 或使用 mc 命令行工具
docker run --rm -it --network=follow-server_follow-network \
  minio/mc alias set myminio http://minio:9000 admin password
docker run --rm -it --network=follow-server_follow-network \
  minio/mc mb myminio/follow-music
```

### 3. 内存不足导致服务崩溃

**解决**: 
```yaml
# 在 docker-compose.yml 中添加资源限制
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### 4. 音频文件上传失败

**原因**: 文件大小超过限制

**解决**:
- 检查 Nginx `client_max_body_size` 配置
- 检查 ASP.NET Core 的请求限制配置

### 5. JWT Token 无效

**原因**: 生产环境和开发环境使用了不同的 SecretKey

**解决**: 确保 `appsettings.Production.json` 中的 `JwtSettings.SecretKey` 配置正确，并重启 API 服务

---

## 附录

### 快速部署检查清单

- [ ] 服务器系统已更新
- [ ] Docker 和 Docker Compose 已安装
- [ ] 防火墙规则已配置
- [ ] 项目源码已上传至 `/opt/follow-server`
- [ ] 生产配置文件已修改 (`appsettings.Production.json`)
- [ ] 环境变量已配置 (`.env`)
- [ ] Docker 服务已启动 (`docker compose up -d --build`)
- [ ] API 健康检查通过 (`curl http://localhost:5000/health`)
- [ ] Nginx 反向代理已配置 (可选)
- [ ] SSL 证书已安装 (可选)
- [ ] 备份策略已配置

### 服务端口汇总

| 端口 | 协议 | 用途 | 对外开放 |
|------|------|------|----------|
| 22 | TCP | SSH | ✅ 是 |
| 80 | TCP | HTTP | ✅ 是 |
| 443 | TCP | HTTPS | ✅ 是 |
| 5000 | TCP | Follow API | ⚠️ 视情况 |
| 5432 | TCP | PostgreSQL | ❌ 否 |
| 6379 | TCP | Redis | ❌ 否 |
| 9000 | TCP | MinIO API | ❌ 否 |
| 9001 | TCP | MinIO Console | ⚠️ 管理用 |

### 相关资源

- [.NET 10 下载](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Docker 安装文档](https://docs.docker.com/engine/install/)
- [MinIO 文档](https://docs.min.io/)
- [Nginx 配置指南](https://nginx.org/en/docs/)
- [Let's Encrypt 证书](https://letsencrypt.org/)
