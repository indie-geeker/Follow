import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension methods for AsyncValue to simplify common patterns
extension AsyncValueExt<T> on AsyncValue<T> {
  /// Returns the value if available, otherwise returns the default value.
  /// Handles loading and error states by returning the default.
  T valueOr(T defaultValue) => when(
        data: (v) => v,
        loading: () => defaultValue,
        error: (_, __) => defaultValue,
      );

  /// Returns the value if available, otherwise returns null.
  T? valueOrNull() => whenOrNull(data: (v) => v);
}

/// Extension for nullable AsyncValue
extension AsyncValueNullableExt<T> on AsyncValue<T?> {
  /// Returns the value if available and not null, otherwise returns the default.
  T valueOrDefault(T defaultValue) => when(
        data: (v) => v ?? defaultValue,
        loading: () => defaultValue,
        error: (_, __) => defaultValue,
      );
}
