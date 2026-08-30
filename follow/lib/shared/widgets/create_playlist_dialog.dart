import 'package:flutter/material.dart';

typedef CreatePlaylistCallback = Future<void> Function(String name);

Future<bool?> showCreatePlaylistDialog(
  BuildContext context, {
  required CreatePlaylistCallback onCreate,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CreatePlaylistDialog(onCreate: onCreate),
  );
}

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key, required this.onCreate});

  final CreatePlaylistCallback onCreate;

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      !_isSubmitting && _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreate(_nameController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = '创建失败，请检查网络后重试';
      });
      _nameFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetAnimationDuration: const Duration(milliseconds: 200),
        insetAnimationCurve: Curves.easeOutCubic,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primaryContainer,
                              colors.secondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.library_music_rounded,
                          color: colors.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('新建歌单', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              '为喜欢的音乐留一个专属位置',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('create-playlist-name'),
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    autofocus: true,
                    enabled: !_isSubmitting,
                    maxLength: 50,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '歌单名称',
                      hintText: '例如：周末公路音乐',
                      helperText: '最多 50 个字符',
                      prefixIcon: Icon(Icons.queue_music_rounded),
                    ),
                    onChanged: (_) {
                      setState(() => _errorMessage = null);
                    },
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入歌单名称';
                      }
                      return null;
                    },
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _errorMessage == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('create-playlist-error'),
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: colors.onErrorContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const ValueKey('create-playlist-submit'),
                          onPressed: _canSubmit ? _submit : null,
                          icon: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                          label: Text(_isSubmitting ? '创建中' : '创建歌单'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
