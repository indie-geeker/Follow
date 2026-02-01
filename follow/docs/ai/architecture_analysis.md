# Follow Flutter 客户端架构分析

## 1. 项目概览

Follow Music 是一个基于 Flutter 开发的跨平台音乐播放器应用。项目采用现代化的 Flutter 开发实践，支持 Android、iOS 和桌面端（MacOS/Windows/Linux），具备响应式布局能力，能够根据屏幕尺寸自动切换移动端和桌面端 UI。

## 2. 技术栈 (Tech Stack)

核心依赖库如下：

*   **UI 框架**: Flutter
*   **语言**: Dart
*   **状态管理**: [Riverpod](https://riverpod.dev/) (v3.x, 使用 `riverpod_annotation` + `riverpod_generator` 代码生成)
*   **路由管理**: [AutoRoute](https://pub.dev/packages/auto_route) (v10.x, 支持声明式路由和守卫)
*   **网络请求**: [Dio](https://pub.dev/packages/dio) (v5.x, 封装了拦截器和 Token 刷新机制)
*   **数据模型**: [Freezed](https://pub.dev/packages/freezed) & [JsonSerializable](https://pub.dev/packages/json_serializable) (不可变对象与 JSON 序列化)
*   **音频播放**: [Just Audio](https://pub.dev/packages/just_audio) & [Audio Service](https://pub.dev/packages/audio_service) (后台播放支持)
*   **本地存储**: [Shared Preferences](https://pub.dev/packages/shared_preferences) (简单的键值对存储)
*   **依赖注入**: 通过 Riverpod 实现
*   **国际化**: `flutter_localizations`

## 3. 架构设计 (Architecture)

项目采用 **Feature-First (按功能分层)** 的架构模式，结合了清洗架构 (Clean Architecture) 的部分理念。

### 3.1 目录结构 (`lib/`)

```
lib/
├── core/                # 核心基础设施 (全局通用)
│   ├── config/          # 应用配置 (常量, Env)
│   ├── l10n/            # 国际化资源
│   └── theme/           # 主题定义 (Light/Dark mode)
│
├── data/                # 数据层 (共享数据)
│   ├── models/          # 数据实体 (User, Track 等)
│   ├── providers/       # Riverpod Providers (Auth, Audio, Lyrics 等)
│   └── services/        # 外部服务封装 (Api, LocalStorage)
│       └── api/         # API 客户端封装 (Retries, Interceptors)
│
├── features/            # 功能模块 (业务核心)
│   ├── auth/            # 认证模块 (登录/注册页面)
│   ├── home/            # 首页模块
│   ├── library/         # 音乐库模块
│   ├── player/          # 播放器模块 (UI & 逻辑)
│   ├── search/          # 搜索模块
│   ├── downloads/       # 下载模块
│   └── settings/        # 设置模块
│
├── router/              # 路由配置
│   └── app_router.dart  # 路由定义与守卫
│
├── shared/              # 共享 UI 组件
│   └── widgets/         # 通用 Widget (MiniPlayer, CoverImage 等)
│
├── app.dart             # 应用入口 Widget (MaterialApp 配置)
└── main.dart            # 程序入口 (初始化)
```

### 3.2 核心机制

#### 状态管理 (State Management)
项目全面使用 **Riverpod** 进行状态管理。大多数据状态通过 `@riverpod` 注解生成，保证了类型安全和可测试性。
*   `AuthProvider`: 管理登录状态、用户信息。
*   `AudioProvider`: 管理播放队列、播放状态。

#### 路由与导航 (Navigation)
使用 **AutoRoute** 管理路由。
*   **AuthGuard**: 实现了全局路由守卫。在 `router/app_router.dart` 中定义，检查 `SharedPreferences` 中的 Token。如果未登录，强制重定向到 `/login`。
*   **ShellRoute**: 使用 `MainShellPage` 作为主外壳，根据屏幕宽度（`MediaQuery`）动态切换布局：
    *   **Mobile (< 800dp)**: 使用底部导航栏 (`NavigationBar`) + `MiniPlayer`。
    *   **Desktop (>= 800dp)**: 使用侧边栏 (`NavigationRail`) + 底部常驻播放条 (`_DesktopPlayerBar`)。

#### 网络层 (Networking)
基于 **Dio** 封装了 `ApiClient` (`lib/data/services/api/api_client.dart`)。
*   **单例模式**: 维护全局唯一的 Dio 实例。
*   **拦截器 (Interceptors)**:
    *   `AuthInterceptor`: 自动在请求头添加 `Bearer Token`。
    *   **401 处理**: 捕获 401 Unauthorized 错误，自动尝试调用 `/api/auth/refresh` 刷新 Token。如果刷新成功，重试原请求；如果失败，触发 `onUnauthorized` 回调强制登出。

#### 音频播放系统 (Audio System)
*   核心逻辑位于 `features/player` 和 `data/providers`。
*   通过 `AudioService` 处理后台播放和系统媒体通知。
*   UI 分为三部分：
    1.  **MiniPlayer**: 移动端底部悬浮条。
    2.  **DesktopPlayerBar**: 桌面端底部常驻控制条。
    3.  **PlayerPage**: 全屏播放页 (含歌词、封面)。

## 4. 页面与功能点

根据路由配置 (`AppRouter`)，主要页面如下：

| 路径 (Path) | 页面 (Page) | 功能描述 |
| :--- | :--- | :--- |
| `/login` | `LoginPage` | 用户登录/注册。 |
| `/` | `MainShellPage` | **主界面外壳**，包含响应式布局逻辑。 |
| `/home` | `HomePage` | 推荐、最新音乐展示。 |
| `/library` | `LibraryPage` | 用户音乐库、播放列表管理。 |
| `/search` | `SearchPage` | 搜索歌曲、艺人、专辑。 |
| `/downloads` | `DownloadsPage` | 离线下载管理。 |
| `/settings` | `SettingsPage` | 应用设置 (主题、语言等)。 |
| `/player` | `PlayerPage` | 全屏播放界面。 |
| `/playlist/:id` | `PlaylistDetailPage` | 歌单详情页。 |
| `/artist/:id` | `ArtistDetailPage` | 艺人详情页。 |
| `/album/:id` | `AlbumDetailPage` | 专辑详情页。 |

## 5. 总结

Follow 客户端拥有清晰、可扩展的架构。
*   **优点**: 模块化程度高，Feature-First 结构便于多人协作；响应式设计使得跨平台体验良好；网络层封装完善（自动刷新 Token）；状态管理方案先进（Riverpod Generator）。
*   **核心链路**: 启动 -> `main.dart` -> `AuthGuard` 检查 Token -> (无Token) Login -> (有Token) MainShell -> 根据设备加载 Desktop/Mobile UI。
