import 'package:flutter_test/flutter_test.dart';

import 'package:cubelab/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CubeLabApp());
    expect(find.text('CubeLab'), findsOneWidget);
  });
}
