import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/user.dart';
import 'package:follow/features/settings/session_management_sheet.dart';

void main() {
  final current = SessionInfo(
    id: 'current-session',
    deviceName: 'Family iPhone',
    clientType: 'Flutter',
    createdAt: DateTime.utc(2026, 7, 26, 10),
    lastUsedAt: DateTime.utc(2026, 7, 26, 11),
    expiresAt: DateTime.utc(2026, 8, 25, 10),
    isCurrent: true,
  );
  final other = SessionInfo(
    id: 'other-session',
    deviceName: 'Living Room Mac',
    clientType: 'Flutter',
    createdAt: DateTime.utc(2026, 7, 20, 10),
    lastUsedAt: DateTime.utc(2026, 7, 25, 11),
    expiresAt: DateTime.utc(2026, 8, 19, 10),
    isCurrent: false,
  );

  testWidgets('lists the current and other family devices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionManagementSheet(
            loadSessions: () async => [current, other],
            onRevoke: (_) async {},
            onLogoutAll: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('Family iPhone'), findsOneWidget);
    expect(find.text('Living Room Mac'), findsOneWidget);
    expect(find.byKey(const ValueKey('revoke-other-session')), findsOneWidget);
  });

  testWidgets('revokes another session and refreshes the list', (tester) async {
    var loads = 0;
    String? revokedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionManagementSheet(
            loadSessions: () async {
              loads++;
              return loads == 1 ? [current, other] : [current];
            },
            onRevoke: (session) async => revokedId = session.id,
            onLogoutAll: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('revoke-other-session')));
    await tester.pumpAndSettle();

    expect(revokedId, 'other-session');
    expect(loads, 2);
    expect(find.text('Living Room Mac'), findsNothing);
  });

  testWidgets('logout all delegates to the server callback', (tester) async {
    var logoutAllCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionManagementSheet(
            loadSessions: () async => [current],
            onRevoke: (_) async {},
            onLogoutAll: () async => logoutAllCalls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('logout-all-sessions')));
    await tester.pumpAndSettle();

    expect(logoutAllCalls, 1);
  });
}
