import 'package:flutter_test/flutter_test.dart';
import 'package:nuclew_client/app/nuclew_app.dart';

void main() {
  testWidgets('на входе есть форма', (tester) async {
    await tester.pumpWidget(const NuclewApp());
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Нет аккаунта'), findsOneWidget);
  });

  testWidgets('регистрация показывает почту', (tester) async {
    await tester.pumpWidget(const NuclewApp());
    await tester.tap(find.text('Нет аккаунта'));
    await tester.pump();
    expect(find.text('Зарегистрироваться'), findsOneWidget);
    expect(find.text('Почта'), findsOneWidget);
  });
}
