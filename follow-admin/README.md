# Follow Music Admin

Vue 3 + Element Plus 管理后台

## 功能

- 📊 仪表盘统计
- 🎵 曲目管理（上传/删除/试听/封面/歌词）
- 🎤 艺术家管理
- 💿 专辑管理
- 👥 用户管理

## 开发环境

```bash
# 安装依赖
pnpm install

# 启动开发服务器（自动使用 .env.development）
pnpm dev
```

访问 http://localhost:3000

## 生产环境打包

```bash
# 构建生产版本（自动使用 .env.production）
pnpm build

# 本地预览生产构建
pnpm preview
```

构建产物位于 `dist/` 目录，可部署到任意静态服务器（Nginx、Vercel、Cloudflare Pages 等）。

## 环境配置

| 文件 | 用途 | 加载时机 |
|------|------|----------|
| `.env.development` | 开发环境 | `pnpm dev` |
| `.env.production` | 生产环境 | `pnpm build` |
| `.env.production.local` | 本地生产配置（不提交 Git） | `pnpm build` |

### 配置项

| 变量 | 说明 | 示例 |
|------|------|------|
| `VITE_API_URL` | 后端 API 地址 | `http://localhost:5000` |

### 开发环境 (.env.development)

```
VITE_API_URL=http://localhost:5000
```

### 生产环境 (.env.production)

```
VITE_API_URL=https://api.your-domain.com
```

## Nginx 部署示例

```nginx
server {
    listen 80;
    server_name admin.your-domain.com;
    root /var/www/follow-admin;
    index index.html;

    # SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 代理（可选）
    location /api {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 注意

- 需要先启动后端 API 服务
- 首个注册用户自动成为管理员
- 仅 Admin 角色可登录管理后台
