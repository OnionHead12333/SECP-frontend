import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/auth/presentation/login_page.dart';
import 'package:smart_elderly_care_mobile/features/auth/presentation/register_page.dart';
import 'package:smart_elderly_care_mobile/features/elder/presentation/elder_register_page.dart';

void main() {
  group('TC-WIDGET-01~18 登录/注册页面状态', () {
    testWidgets('TC-WIDGET-01 登录页展示核心字段', (tester) async {
      await _pump(tester, const LoginPage());

      expect(find.text('智慧养老平台'), findsOneWidget);
      expect(find.text('手机号码'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('去注册'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-02 空表单登录提示手机号必填', (tester) async {
      await _pump(tester, const LoginPage());

      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();

      expect(find.text('请输入手机号码'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-03 非手机号输入会提示格式错误', (tester) async {
      await _pump(tester, const LoginPage());

      await tester.enterText(find.byType(TextField).at(0), 'abc');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();

      expect(find.text('请输入11位中国大陆手机号'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-04 未输入密码会提示密码必填', (tester) async {
      await _pump(tester, const LoginPage());

      await tester.enterText(find.byType(TextField).at(0), '13800000000');
      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();

      expect(find.text('请输入密码'), findsWidgets);
    });

    testWidgets('TC-WIDGET-05 短密码会提示至少 6 位', (tester) async {
      await _pump(tester, const LoginPage());

      await tester.enterText(find.byType(TextField).at(0), '13800000000');
      await tester.enterText(find.byType(TextField).at(1), '123');
      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();

      expect(find.text('密码至少 6 位'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-06 密码可见性按钮能切换 tooltip', (tester) async {
      await _pump(tester, const LoginPage());

      expect(find.byTooltip('显示密码'), findsOneWidget);

      await tester.tap(find.byTooltip('显示密码'));
      await tester.pump();

      expect(find.byTooltip('隐藏密码'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-07 登录页可进入注册角色选择页', (tester) async {
      await _pump(tester, const LoginPage());

      await tester.tap(find.text('去注册'));
      await tester.pumpAndSettle();

      expect(find.text('注册老人端'), findsOneWidget);
      expect(find.text('注册子女端'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-08 子女注册入口展示子女表单', (tester) async {
      await _pump(tester, const RegisterPage());

      await tester.tap(find.text('注册子女端'));
      await tester.pumpAndSettle();

      expect(find.text('子女注册'), findsOneWidget);
      expect(find.text('子女姓名'), findsOneWidget);
      expect(find.text('子女手机号'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-09 子女注册空表单提示姓名必填', (tester) async {
      await _pump(tester, const RegisterPage());

      await tester.tap(find.text('注册子女端'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '下一步'));
      await tester.pump();

      expect(find.text('请输入子女姓名'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-10 注册角色选择页可返回登录页', (tester) async {
      await _pump(tester, const LoginPage());

      await tester.tap(find.text('去注册'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已有账号？返回登录'));
      await tester.pumpAndSettle();

      expect(find.text('登录您的账号'), findsOneWidget);
      expect(find.text('去注册'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-11 子女注册页可返回角色选择', (tester) async {
      await _pump(tester, const RegisterPage());
      await _openChildRegister(tester);

      await tester.tap(find.text('返回选择账号类型'));
      await tester.pumpAndSettle();

      expect(find.text('注册老人端'), findsOneWidget);
      expect(find.text('注册子女端'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-12 子女注册缺昵称会提示', (tester) async {
      await _pump(tester, const RegisterPage());
      await _openChildRegister(tester);

      await tester.enterText(find.byType(TextField).at(0), '测试子女');
      await tester.enterText(find.byType(TextField).at(2), '13800000000');
      await tester.enterText(find.byType(TextField).at(3), '123456');
      await tester.enterText(find.byType(TextField).at(4), '123456');
      await _tapChildNext(tester);

      expect(find.text('请输入子女昵称'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-13 子女手机号过短会提示格式错误', (tester) async {
      await _pump(tester, const RegisterPage());
      await _openChildRegister(tester);

      await tester.enterText(find.byType(TextField).at(0), '测试子女');
      await tester.enterText(find.byType(TextField).at(1), '小测');
      await tester.enterText(find.byType(TextField).at(2), '138');
      await tester.enterText(find.byType(TextField).at(3), '123456');
      await tester.enterText(find.byType(TextField).at(4), '123456');
      await _tapChildNext(tester);

      expect(find.text('子女手机号格式不正确'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-14 子女注册两次密码不一致会提示', (tester) async {
      await _pump(tester, const RegisterPage());
      await _openChildRegister(tester);

      await tester.enterText(find.byType(TextField).at(0), '测试子女');
      await tester.enterText(find.byType(TextField).at(1), '小测');
      await tester.enterText(find.byType(TextField).at(2), '13800000000');
      await tester.enterText(find.byType(TextField).at(3), '123456');
      await tester.enterText(find.byType(TextField).at(4), '654321');
      await _tapChildNext(tester);

      expect(find.text('两次密码不一致'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-15 子女注册未同意协议会提示', (tester) async {
      await _pump(tester, const RegisterPage());
      await _openChildRegister(tester);

      await _fillValidChildRegister(tester);
      await _tapChildNext(tester);

      expect(find.text('请先勾选并同意协议'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-16 子女资料完整后进入老人主体信息弹层', (tester) async {
      await _pump(tester, const RegisterPage());
      await _openChildRegister(tester);

      await _fillValidChildRegister(tester);
      await _agreeChildTerms(tester);
      await _tapChildNext(tester);
      await tester.pumpAndSettle();

      expect(find.text('老人主体信息'), findsOneWidget);
      expect(find.text('老人姓名'), findsOneWidget);
      expect(find.text('提交注册'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-17 老人注册页展示核心字段', (tester) async {
      await _pump(tester, const ElderRegisterPage());

      expect(find.text('老人注册'), findsOneWidget);
      expect(find.text('姓名'), findsOneWidget);
      expect(find.text('手机号'), findsOneWidget);
      expect(find.text('确认密码'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-18 老人注册空表单提示姓名必填', (tester) async {
      await _pump(tester, const ElderRegisterPage());

      await tester.ensureVisible(find.widgetWithText(FilledButton, '注册并继续'));
      await tester.tap(find.widgetWithText(FilledButton, '注册并继续'));
      await tester.pump();

      expect(find.text('请输入姓名'), findsOneWidget);
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: child,
    ),
  );
  await tester.pump();
}

Future<void> _openChildRegister(WidgetTester tester) async {
  await tester.tap(find.text('注册子女端'));
  await tester.pumpAndSettle();
}

Future<void> _tapChildNext(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, '下一步'));
  await tester.tap(find.widgetWithText(FilledButton, '下一步'));
  await tester.pump();
}

Future<void> _fillValidChildRegister(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '测试子女');
  await tester.enterText(find.byType(TextField).at(1), '小测');
  await tester.enterText(find.byType(TextField).at(2), '13800000000');
  await tester.enterText(find.byType(TextField).at(3), '123456');
  await tester.enterText(find.byType(TextField).at(4), '123456');
}

Future<void> _agreeChildTerms(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
}
