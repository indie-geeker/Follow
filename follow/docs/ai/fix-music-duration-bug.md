# 修复音乐播放首次点击时长显示异常

## 问题描述

首次点击歌曲时：
- 总时长显示 0:01（而非正确的时长如 4:15）
- 歌曲不播放

再次点击同一首歌曲后，时长和播放都正常。

## 根因分析

问题出在 `playTrack()` 异步调用的时序：

```dart
// library_page.dart (及其他页面)
onTap: () {
  ref.read(currentTrackProvider.notifier).setTrack(track);  // 同步
  ref.read(playQueueProvider.notifier).setQueue(tracks);    // 同步
  ref.read(audioPlayerServiceProvider).playTrack(track);    // 异步，但没有 await
},
```

`playTrack()` 内部：
```dart
Future<void> playTrack(Track track) async {
  await _player.setUrl(...);  // 网络请求，加载元数据
  await _player.play();
}
```

问题：
1. `setUrl()` 是异步操作，需要从服务器获取音频元数据（duration）
2. 调用 `playTrack()` 时没有等待，UI 立即读取未准备好的 duration
3. `mini_player.dart` 中 duration 的默认值是 `Duration(seconds: 1)`
4. `play()` 可能在音频源准备好之前就被调用

## 修复方案

### 方案 A：使用 `just_audio` 的加载状态（推荐）

监听 `processingStateStream`，确保在音频加载完成后才开始播放：

```dart
// audio_provider.dart
Future<void> playTrack(Track track) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  if (track.isDownloaded && track.localPath != null) {
    await _player.setFilePath(track.localPath!);
  } else {
    final url = _apiService.getStreamUrl(track.id);
    await _player.setUrl(
      url,
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );
  }

  // setUrl 完成后，duration 已经可用
  // 直接播放
  await _player.play();
}
```

实际上当前代码已经正确使用了 `await`。问题在于**调用方没有等待**。

### 方案 B：在调用处等待（简单修复）

```dart
// library_page.dart
onTap: () async {
  ref.read(currentTrackProvider.notifier).setTrack(track);
  ref.read(playQueueProvider.notifier).setQueue(tracks);
  await ref.read(audioPlayerServiceProvider).playTrack(track);
},
```

但这不会解决 UI 立即显示的问题，因为 `setTrack` 已经触发了 UI 更新。

### 方案 C：在 duration 流初始化时提供 loading 状态（推荐）

真正的问题是：在 `setUrl()` 完成之前，`durationStream` 发出的值是 `null`，被 UI 转换为 1 秒。

修复：在 `mini_player.dart` 中，当 duration 为 null 或过小时，显示加载指示或使用 Track 模型中的 `durationSeconds`：

```dart
// mini_player.dart
final duration = durationAsync.when(
  data: (v) {
    // 如果播放器返回的 duration 无效，使用 track 中存储的时长
    if (v == null || v.inSeconds <= 1) {
      return Duration(seconds: currentTrack.durationSeconds);
    }
    return v;
  },
  loading: () => Duration(seconds: currentTrack.durationSeconds),
  error: (_, __) => Duration(seconds: currentTrack.durationSeconds),
);
```

## 推荐实施

采用**方案 C**，因为：
1. Track 模型已包含 `durationSeconds` 字段，存储了服务器端的歌曲时长
2. 在播放器加载完成前，使用此预存时长显示
3. 一旦播放器准备好，自动切换到播放器的实时 duration

## 需要修改的文件

1. `lib/shared/widgets/mini_player.dart` - 使用 track 的 durationSeconds 作为回退值
2. `lib/features/player/player_page.dart` - 同样的逻辑（如果有独立的播放页面）

## 风险评估

- 低风险：只是修改默认值的来源
- 无破坏性：不改变现有的异步播放逻辑
