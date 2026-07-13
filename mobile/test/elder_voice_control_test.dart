import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_elderly_care_mobile/core/network/api_client.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_matcher.dart';
import 'package:smart_elderly_care_mobile/features/elder/data/elder_voice_command_executor.dart';
import 'package:smart_elderly_care_mobile/features/elder/elder_module_routes.dart';
import 'package:smart_elderly_care_mobile/features/elder/presentation/elder_home_page.dart';
import 'package:smart_elderly_care_mobile/features/elder/presentation/elder_voice_control_page.dart';

void main() {
  test('voice command matcher maps required entertainment and help phrases',
      () {
    expect(VoiceCommandMatcher.match('播放音乐').standardCommand, 'play_music');
    expect(VoiceCommandMatcher.match('跳舞').standardCommand, 'dance');
    expect(VoiceCommandMatcher.match('开始表演').standardCommand, 'dance');
    expect(VoiceCommandMatcher.match('求助').standardCommand, 'help');
    expect(VoiceCommandMatcher.match('help').standardCommand, 'help');
    expect(VoiceCommandMatcher.match('停止').standardCommand, 'stop');
  });

  test('voice executor calls entertainment play and dance endpoints', () async {
    final captured = <String>[];
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options.path);
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: {
              'code': 0,
              'message': 'ok',
              'data': {
                'taskId': options.path.endsWith('/dance/start') ? 'd1' : 'p1',
                'status': 'sent',
                'feedback': '命令已发送',
              },
            },
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    final play = await ElderVoiceCommandExecutor.execute(
      VoiceCommandMatcher.match('播放音乐'),
    );
    final dance = await ElderVoiceCommandExecutor.execute(
      VoiceCommandMatcher.match('开始表演'),
    );

    expect(captured, contains('/api/entertainment/music/play'));
    expect(captured, contains('/api/entertainment/dance/start'));
    expect(play.taskId, 'p1');
    expect(play.status, 'sent');
    expect(play.feedback, contains('命令已发送'));
    expect(dance.taskId, 'd1');
    expect(dance.standardCommand, 'dance');
  });

  test(
      'voice executor degrades instead of throwing when backend is unavailable',
      () async {
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 404,
              data: {'message': 'not found'},
            ),
            message: 'not found',
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    final result = await ElderVoiceCommandExecutor.execute(
      VoiceCommandMatcher.match('播放音乐'),
    );

    expect(result.standardCommand, 'play_music');
    expect(result.status, 'failed');
    expect(result.feedback, contains('降级'));
  });

  testWidgets('elder home exposes voice control entry', (tester) async {
    final interceptor = _rejectBackgroundRequests();
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    SharedPreferences.setMockInitialValues(
      {'elder_login_permission_guide_shown_v1': true},
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          ElderModuleRoutes.elderVoiceControl: (_) =>
              const ElderVoiceControlPage(),
        },
        home: const ElderHomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('语音控制'), findsOneWidget);
  });
}

Interceptor _rejectBackgroundRequests() {
  return InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          data: const {'code': 5000, 'message': 'test offline'},
        ),
      );
    },
  );
}
