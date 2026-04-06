import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/app/smart_elderly_care_app.dart';

void main() {
  testWidgets('应用能启动并进入登录页', (tester) async {
    await tester.pumpWidget(const SmartElderlyCareApp());
    expect(find.text('登录'), findsWidgets);
    expect(find.text('智慧养老平台'), findsOneWidget);
  });
}
