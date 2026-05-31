import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_connect/screens/onboarding/role_pick_screen.dart';

void main() {
  testWidgets('Role pick screen shows all roles', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RolePickScreen(onRoleSelected: (_) {}),
      ),
    );

    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Advisor'), findsOneWidget);
    expect(find.text('Sub Teacher'), findsOneWidget);
    expect(find.text('HOD'), findsOneWidget);
  });
}
