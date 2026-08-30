import 'package:flutter/material.dart';
import 'package:follow/data/models/user.dart';

typedef LoadSessions = Future<List<SessionInfo>> Function();
typedef RevokeSession = Future<void> Function(SessionInfo session);

class SessionManagementSheet extends StatefulWidget {
  const SessionManagementSheet({
    required this.loadSessions,
    required this.onRevoke,
    required this.onLogoutAll,
    super.key,
  });

  final LoadSessions loadSessions;
  final RevokeSession onRevoke;
  final Future<void> Function() onLogoutAll;

  @override
  State<SessionManagementSheet> createState() => _SessionManagementSheetState();
}

class _SessionManagementSheetState extends State<SessionManagementSheet> {
  late Future<List<SessionInfo>> _sessions;
  String? _busySessionId;
  bool _loggingOutAll = false;

  @override
  void initState() {
    super.initState();
    _sessions = widget.loadSessions();
  }

  void _reload() {
    setState(() => _sessions = widget.loadSessions());
  }

  Future<void> _revoke(SessionInfo session) async {
    if (_busySessionId != null || _loggingOutAll) return;
    setState(() => _busySessionId = session.id);
    try {
      await widget.onRevoke(session);
      if (!mounted) return;
      if (!session.isCurrent) _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法撤销该设备，请稍后重试')));
    } finally {
      if (mounted) setState(() => _busySessionId = null);
    }
  }

  Future<void> _logoutAll() async {
    if (_busySessionId != null || _loggingOutAll) return;
    setState(() => _loggingOutAll = true);
    try {
      await widget.onLogoutAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法退出所有设备，本机会话已保留')));
    } finally {
      if (mounted) setState(() => _loggingOutAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '登录设备',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '撤销不认识或不再使用的家庭设备会话。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<List<SessionInfo>>(
                  future: _sessions,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: FilledButton.tonalIcon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重试'),
                        ),
                      );
                    }
                    final sessions = snapshot.data ?? const <SessionInfo>[];
                    if (sessions.isEmpty) {
                      return const Center(child: Text('暂无活跃设备'));
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final busy = _busySessionId == session.id;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            session.isCurrent
                                ? Icons.smartphone_rounded
                                : Icons.devices_rounded,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  session.deviceName?.trim().isNotEmpty == true
                                      ? session.deviceName!.trim()
                                      : session.clientType,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (session.isCurrent) ...[
                                const SizedBox(width: 8),
                                const Chip(
                                  label: Text('当前设备'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '最近使用 ${_formatTime(session.lastUsedAt)}',
                          ),
                          trailing: IconButton(
                            key: ValueKey('revoke-${session.id}'),
                            tooltip: session.isCurrent ? '退出本机' : '撤销设备',
                            onPressed: busy ? null : () => _revoke(session),
                            icon: busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout_rounded),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('logout-all-sessions'),
                onPressed: _loggingOutAll ? null : _logoutAll,
                icon: _loggingOutAll
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.phonelink_erase_rounded),
                label: const Text('退出所有设备'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
