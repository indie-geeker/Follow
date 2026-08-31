# Follow

Follow 是家庭音乐服务的单仓库，包含 .NET API、Vue 管理后台和 Flutter 客户端。完整的本地运行说明见 [`follow-server/README.md`](follow-server/README.md)。

音乐初始化与浏览器上传都先进入分析和人工复核，不会在分析阶段自动创建正式曲目。API 镜像固定使用官方 `fpcalc 1.6.1` 发布包，并按 amd64/arm64 分别校验 SHA-256；指纹就绪失败时 `/health/ready` 返回失败，容器不会被标记为可用。

目录初始化必须显式叠加 `docker-compose.import.yml`，并把已经存在的宿主机目录只读挂载到 `/imports/library`。生产组合文件 `docker-compose.prod.yml` 复用同一只读约束；不要把真实路径或凭据提交到版本库。
