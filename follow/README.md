# Follow Music

跨平台音乐播放器 Flutter 客户端

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
- **下载**: background_downloader
- **主题**: Material 3
- **国际化**: 中文/英文

## 配置

API 地址可通过编译参数配置：

```bash
flutter run --dart-define=API_URL=https://your-api.com
```

默认: `http://localhost:5000`
