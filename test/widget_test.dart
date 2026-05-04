import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teawnaid/main.dart';

void main() {
  testWidgets('shows travel randomizer controls', (tester) async {
    await tester.pumpWidget(const ThailandRandomTravelApp(adsEnabled: false));

    expect(find.text('TeawNaiD'), findsOneWidget);
    expect(find.text('สุ่มที่เที่ยวไทย...ไปได้ทุกที่'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.drag(find.byType(Scrollable), const Offset(0, -820));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('สุ่ม แล้วไปเที่ยวกัน!'), findsOneWidget);
    expect(find.text('สุ่มเลย!'), findsOneWidget);
  });
}
