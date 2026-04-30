import 'package:banka/app/app.dart';
import 'package:banka/core/di/injector.dart';
import 'package:banka/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerLazySingleton<AppRouter>(AppRouter.new);
  });

  testWidgets('BankaApp boots and shows the splash screen', (tester) async {
    await tester.pumpWidget(const BankaApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('banka'), findsOneWidget);
  });

  testWidgets('Splash auto-navigates to SignIn after delay', (tester) async {
    await tester.pumpWidget(const BankaApp());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Войти через Google'), findsOneWidget);
  });
}
