import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soultalk_pc/main.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SoulTalkPCApp()));
    await tester.pumpAndSettle();
    expect(find.text('SoulTalk PC'), findsOneWidget);
  });
}
