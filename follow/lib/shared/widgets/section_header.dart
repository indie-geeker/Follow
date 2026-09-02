import 'package:flutter/material.dart';

import '../../core/theme/follow_theme_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  }) : assert(
         actionLabel == null || onAction != null,
         'An action label requires an action callback.',
       );

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.followTokens;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: tokens.brandPrimary,
                minimumSize: Size(0, tokens.minimumTapTarget),
                textStyle: theme.textTheme.labelLarge,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
