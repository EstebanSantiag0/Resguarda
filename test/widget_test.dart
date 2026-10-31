import 'package:flutter_test/flutter_test.dart';
import 'package:resguarda/main.dart';

void main() {
  testWidgets('La pantalla de inicio muestra las situaciones', (tester) async {
    await tester.pumpWidget(const Resguarda());
    await tester.pumpAndSettle();
    expect(find.text('¿Qué está pasando?'), findsOneWidget);
    expect(find.text('Llamar al 911'), findsOneWidget);
  });
}
