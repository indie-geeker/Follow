import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/follow_theme_tokens.dart';

class StateIllustrationColorMapper extends ColorMapper {
  const StateIllustrationColorMapper(this.tokens);

  final FollowThemeTokens tokens;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => switch (color.toARGB32()) {
    0xFFFF00FF => tokens.brandPrimary,
    0xFF00FFFF => tokens.brandSecondary,
    0xFF808080 => tokens.surfaceElevated,
    0xFF000000 => tokens.textSecondary,
    _ => color,
  };
}
