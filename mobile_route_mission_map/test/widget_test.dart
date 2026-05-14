import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_route_mission_map/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const RouteMissionApp());
    expect(find.text('Rota Görev Haritası'), findsOneWidget);
  });
}
