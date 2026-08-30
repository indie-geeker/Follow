# Follow 家庭音乐服务部署指南

本文描述当前仓库的本机 Compose 边界以及上线要求：仓库不再内置 TLS 网关；网页管理后台与 API 仍必须通过运维提供的 HTTPS origin 对外服务。PostgreSQL、Redis 与 MinIO 不作为家庭网络中的独立服务暴露。

## 1. 网络边界

```text
家庭浏览器 / Follow App
          |
   运维提供的 HTTPS 入口
          |
  127.0.0.1:3000 Admin Nginx
      /api       其他路径
       |          Admin SPA
   API:5000（Docker 内网）
       |
 PostgreSQL / Redis / MinIO（Docker 内网）

Android Emulator Debug -- HTTP 10.0.2.2:5050 --> API
```

根目录 `docker-compose.yml` 的端口策略：

| 服务 | 宿主机端口 | 作用域 |
|---|---:|---|
| API | `127.0.0.1:5050` | 本机诊断与 Android Emulator Debug |
| PostgreSQL | 无宿主机端口 | 通过 `docker compose exec postgres ...` 维护 |
| Redis | 无宿主机端口 | 通过 `docker compose exec redis ...` 维护 |
| Admin | `127.0.0.1:3000` | 本机管理后台；Nginx 将 `/api/*` 代理到内部 API |
| MinIO API / Console | 无 | 仅 API 容器访问 |

不要为 MinIO 增加 `ports`，也不要让 App 或浏览器持有 MinIO 地址和密钥。封面与音频均通过受约束的 API 路由访问。

## 2. 前置条件

- Docker Engine 与 Docker Compose v2
- 一台在家庭网络中地址稳定的主机
- 上线时使用的真实域名和公共可信 TLS 证书
- 能转发到宿主机 `127.0.0.1:3000` 的独立 HTTPS 反向代理或负载均衡器
- 迁移前数据库备份空间

本地 Docker 健康检查使用 `http://127.0.0.1:5050`。手机、浏览器或其他电脑不得直接访问本地 HTTP 端口；上线客户端编译时的 `API_URL` 必须使用运维提供的真实 HTTPS origin。

## 3. 配置

在仓库根目录执行：

```bash
cp .env.example .env
chmod 600 .env
```

至少替换以下值：

```dotenv
POSTGRES_USER=follow
POSTGRES_DB=follow
POSTGRES_PASSWORD=使用随机生成的数据库强密码

JWT_SECRET=至少32字符的高熵随机值

ADMIN_USERNAME=admin
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=同时包含大小写字母数字和特殊字符的强密码

MINIO_ROOT_USER=follow
MINIO_ROOT_PASSWORD=使用随机生成的对象存储强密码
```

Admin 与 API 共享 `internal` web 网络，Admin Nginx 只代理 `/api/*`；API、PostgreSQL、Redis 与 MinIO 共享独立的 `internal` data 网络。宿主机端口显式绑定 `127.0.0.1`，不能改成 `0.0.0.0` 作为上线捷径。若生产代理提供 `X-Forwarded-*`，只将该代理的确定地址或专用网络加入 `ForwardedHeaders` 信任列表。

不要提交 `.env`。环境管理员密码是启动配置的权威值；修改后重启 API 会使环境管理员的数据库密码同步更新。

## 4. 部署前门禁

先验证配置和构建，不触碰数据库：

```bash
docker compose config --quiet
bash scripts/verify-docker-config.sh
docker compose build api admin
```

任何一步失败都应停止，不要继续迁移。

## 5. 备份现有数据库

先启动或确认 PostgreSQL 正常：

```bash
docker compose up -d postgres
docker compose ps postgres
```

创建自定义格式备份：

```bash
mkdir -p .local-backups
chmod 700 .local-backups
docker compose exec -T postgres sh -lc 'exec pg_dump --format=custom --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"' > .local-backups/follow-before-migration.dump
chmod 600 .local-backups/follow-before-migration.dump
docker run --rm -v "$PWD/.local-backups:/backups:ro" postgres:18 pg_restore --list /backups/follow-before-migration.dump
```

最后一条命令必须能列出表、数据和约束。将备份复制到 Docker 主机之外再继续。

本次家庭音乐迁移会删除旧订阅功能的数据表；恢复旧版本必须使用迁移前备份，不能假设向下迁移能恢复已删除的数据。

## 6. 依赖、迁移与启动

按依赖顺序执行：

```bash
docker compose up -d postgres redis minio
docker compose ps
docker compose up -d api
docker compose logs --tail=200 api
```

API 启动时应用 EF Core 迁移。日志中必须没有迁移失败、数据库连接失败或 MinIO 初始化失败，然后再启动用户入口：

```bash
docker compose up -d admin
docker compose ps
```

禁止使用 `docker compose down -v`；它会删除持久化卷。

## 7. 配置生产 HTTPS 入口

仓库不绑定具体网关产品。生产环境必须由宿主机或基础设施提供以下能力：

- 使用真实域名和公共可信证书监听 HTTPS `443`；
- 把请求转发到 `127.0.0.1:3000`，由 Admin Nginx 继续分流静态页面和 `/api/*`；
- 保留 Range、Authorization、Cookie 与请求体流，不缓存认证 API 或音频响应；
- 只在明确配置可信代理后传递并信任 `X-Forwarded-For` / `X-Forwarded-Proto`；
- 禁止从公网直接连接 `3000`、`5050`、PostgreSQL、Redis 或 MinIO。

Release App 只接受 HTTPS，不安装或注入仓库私有 CA。证书部署、续期和回滚由选定的生产网关负责。

## 8. 验收

在服务器本机验证容器与 API：

```bash
docker compose ps
curl --fail http://127.0.0.1:5050/health
curl --fail --head http://127.0.0.1:3000/
```

在家庭设备上验证生产 HTTPS 入口：

```bash
curl --fail https://music.home.arpa/health
curl --fail --head https://music.home.arpa/
```

然后执行产品验收：

1. 管理后台登录；开发者工具中不得出现保存在 Local Storage / Session Storage 的 token。
2. 同一账号登录两台设备，能看到两个独立会话；撤销其中一个不会影响另一个。
3. 注销后旧 Access Token 立即失效，旧 Refresh Token 不能再次换取 token。
4. 对登录与刷新接口做短时重复请求，确认返回限流响应，而不是继续消耗密码校验或数据库资源。
5. 上传一首音乐，浏览器 Network 中播放请求应带 `Range`；服务端返回 `206`、`Accept-Ranges: bytes` 和正确的 `Content-Range`。
6. 删除曲目后数据库引用立即消失；对象清理任务最终删除音频、封面与歌词。重复执行清理任务应保持成功。
7. Member 不能修改其他用户的公开播放列表；列表分页连续读取时不重复、不跳项。
8. 从家庭网络另一台机器确认 9000/9001 无法连接，MinIO Console 不可见。

## 9. 日志与备份

```bash
docker compose logs --tail=200 api
docker compose logs --tail=200 minio
```

至少定期备份：

- PostgreSQL 自定义格式 dump
- MinIO 数据卷或其底层存储快照
- 当前 `.env` 的加密副本
- 生产 HTTPS 网关的独立配置和证书恢复方案

数据库与 MinIO 必须来自同一备份时间点，否则数据库对象键与实际对象可能不一致。

## 10. 回滚

若 API 迁移或验收失败：

```bash
docker compose stop admin api
```

保留现场日志和当前卷，不要执行 `down -v`。推荐把 `.local-backups/follow-before-migration.dump` 恢复到一个新的临时数据库中验证，再由维护者明确决定是否替换当前数据库。回滚应用版本时，数据库必须同时恢复到与该版本兼容的迁移点。

恢复后重新执行第 8 节；只有数据库、对象存储、API 与客户端契约同时通过才算回滚完成。

## 11. 本地开发例外

Vite 开发服务器只使用相对 `/api`，由 `follow-admin/vite.config.ts` 代理到本机 API。Flutter Android Debug 默认通过官方 Emulator 宿主机别名直连 `http://10.0.2.2:5050`，不需要启动参数；Android 网络策略只对 Debug 的这个地址放行 HTTP。Profile、Release 和所有非本地 origin 仍强制 HTTPS。

这些开发例外不能复制到家庭部署配置，也不能把绝对 API origin 编译进管理后台。
