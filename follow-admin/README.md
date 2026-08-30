# Follow 家庭音乐管理后台

Vue 3 + Element Plus 管理后台

## 功能

- 📊 仪表盘统计
- 🎵 曲目管理（上传/删除、Range 流式试听、封面/歌词）
- 🎤 艺术家管理
- 💿 专辑管理
- 👥 用户管理（创建/邀请、角色调整、删除）

## 开发环境

```bash
# 安装依赖
pnpm install

# 启动开发服务器（自动使用 .env.development）
pnpm dev
```

开发服务器通过 Vite 将相对 `/api` 请求代理到本机 API。完整 Docker 栈统一从 `https://localhost`（或 `.env` 中配置的家庭域名）访问。

## 生产环境打包

```bash
# 构建生产版本（自动使用 .env.production）
pnpm build

# 本地预览生产构建
pnpm preview
```

构建产物位于 `dist/`。生产环境必须把静态页面与 `/api` 部署在同一 HTTPS origin，不能再把 API 绝对地址编入 JavaScript。

## 同源认证

- 浏览器不保存 Access Token 或 Refresh Token。
- 登录、刷新和播放请求依赖同源的 Secure、HttpOnly Cookie。
- 页面启动时先通过 `/api/auth/me` 检查 Access Cookie，仅在 `401` 时轮换 Refresh Token，再进入受保护路由。
- 同一标签页的并发 `401` 只触发一次刷新；支持 Web Locks 的现代浏览器还会跨标签页串行化刷新并在持锁后重查 Access Cookie。生产管理后台以支持 Web Locks 为浏览器基线。
- 刷新成功后每个请求最多重放一次；重放仍为 `401` 时回到登录页。
- 退出登录会先调用服务端注销当前设备会话，再清理前端状态；不能只删除本地状态。

## 容器部署

根目录 Compose 将管理后台绑定到宿主机 `127.0.0.1:3000`。容器内 Nginx 把 `/api/*` 反向代理到 API，其余路径提供静态站点，因此生产构建中的请求和音频 URL 继续保持同源相对路径；MinIO 不对浏览器开放。

上线时必须在宿主机 loopback 端口前配置独立的 HTTPS 反向代理或负载均衡器，并使用公共可信证书。不要把 `3000`、`5050` 或 MinIO 端口绑定到公网网卡。

## 注意

- 需要先启动后端 API 服务
- 管理员账号由根目录 `.env` 中的 `ADMIN_USERNAME`、`ADMIN_EMAIL`、`ADMIN_PASSWORD` 维护
- “邀请用户”会直接创建账号并生成临时密码；当前不会自动发送邮件
- 仅 Admin 角色可登录管理后台
