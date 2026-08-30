# Follow 家庭音乐

面向家庭成员的跨平台音乐库与播放器 Flutter 客户端。

## 平台支持

- Android
- iOS
- macOS
- Windows

## 开发

```bash
# 获取依赖
flutter pub get

# 代码生成
dart run build_runner build

# 运行
flutter run
```

## 技术栈

- **状态管理**: Riverpod + Generator
- **路由**: auto_router
- **数据模型**: freezed
- **网络**: Dio
- **音频**: just_audio + audio_service
- **凭据**: flutter_secure_storage
- **下载**: background_downloader
- **主题**: Material 3
- **国际化**: 中文/英文

## 配置

API 地址可通过编译参数配置，必须是不带 path、query、fragment 和用户信息的 origin：

```bash
flutter run --dart-define=API_URL=https://your-api.com
```

本地 Debug 已内置开发地址：

- Android Emulator：`http://10.0.2.2:5050`
- 桌面和 Flutter Web：`http://localhost:5050`

先在仓库根目录启动 API：

```bash
cd ..
docker compose up -d --build api
```

然后在 Android Studio 中选择 Emulator，直接点击 Run 即可。不需要 `API_URL` 参数、证书安装、ADB reverse 或额外准备脚本。如果此前在 Run Configuration 中添加过 `--dart-define-from-file=.env.android.local`，请删除该参数。

Android Emulator 使用 `10.0.2.2` 访问宿主机 loopback。Android Debug 网络策略只对这个地址放行 HTTP；`10.0.0.2` 不是官方 Emulator 的宿主机别名。

Profile、Release 以及所有非本地地址仍强制使用 HTTPS。本地 HTTP 例外不能用于真机、局域网或上线构建。生产构建必须显式传入真实 HTTPS origin：

```bash
fvm flutter build appbundle --release \
  --dart-define=API_URL=https://music.example.com
```

物理设备上的 `localhost` 指向设备自身；真机联调也必须使用可解析、与证书 SAN 一致的 HTTPS 域名。

## 客户端契约

- 登录和刷新使用 `tokenTransport: body`。Access Token 和 Refresh Token 作为一个值写入 Keychain/Keystore 安全存储；本地安装 ID 也在安全存储中，不作为认证凭据发给服务端。“记住我”最多保存邮箱，不保存密码。
- 收到 `401` 时并发请求共享一次 Refresh Token 轮换，每个请求最多重放一次。只有 Refresh 明确返回 `400/401/409` 时清除认证态；断网、超时、格式错误或 `5xx` 保留安全凭据以便重试。
- 退出登录先调用 `POST /api/auth/logout` 撤销当前服务端会话，只在服务端确认后清理本地账号、播放队列和敏感状态；断网时保留会话以便重试。设置页可查看、逐个撤销设备，或通过 `logout-all` 注销全部设备。
- 播放器使用 `/api/tracks/{id}/stream` 的 Range 能力，支持暂停、拖动和断点读取，不预先下载整首音乐到内存。
- 鉴权播放禁用 `just_audio` 的明文 localhost header proxy，Bearer Header 由平台原生媒体实现发送。iOS/macOS 路径依赖 AVFoundation 的 header 能力，发布前必须用目标系统版本实机验证后台播放、锁屏恢复和 Range seek。
- 公开歌单对非所有者只读；现有增删曲目入口以服务端返回的所有权/`canEdit` 为准，后续编辑、删除或重排入口也必须沿用该能力字段。曲库 tracks 列表按服务端分页元数据继续加载；artists/albums 仍按服务端数组契约解析。

Darwin 平台已为 `flutter_secure_storage` 配置 Keychain entitlement。本地无签名编译可用 `CODE_SIGNING_ALLOWED=NO`；真机安装、发布和 Keychain 能力仍必须在 Xcode 中使用对应 Team/Provisioning Profile 签名验证。
