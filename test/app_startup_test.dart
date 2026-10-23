import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arco_analytics/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app abre e entra no modo demo', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ArcoApp(autoSync: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ARCO Analytics'), findsOneWidget);
    expect(find.text('Entrar como Adriano Mião (demo)'), findsOneWidget);

    await tester.tap(find.text('Entrar como Adriano Mião (demo)'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Olá, Adriano Mião'), findsOneWidget);
    expect(find.text('Central de decisão'), findsOneWidget);
  });
}
