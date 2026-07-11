import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_elderly_care_mobile/core/auth/auth_session.dart';
import 'package:smart_elderly_care_mobile/core/network/api_client.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_api.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_matcher.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_models.dart';
import 'package:smart_elderly_care_mobile/core/voice/voice_command_recognizer_service.dart';
import 'package:smart_elderly_care_mobile/features/elder/data/elder_help_api.dart';
import 'package:smart_elderly_care_mobile/features/elder/elder_module_routes.dart';
import 'package:smart_elderly_care_mobile/features/elder/presentation/elder_home_page.dart';
import 'package:smart_elderly_care_mobile/features/elder/presentation/elder_voice_control_page.dart';

void main() {
  setUp(() {
    AuthSession.clear();
    SharedPreferences.setMockInitialValues(
      <String, Object>{'elder_login_permission_guide_shown_v1': true},
    );
  });

  tearDown(AuthSession.clear);

  test('matcher returns unmatched for unrelated text', () {
    final match = VoiceCommandMatcher.match('明天天气不错');

    expect(match.commandType, isNull);
    expect(match.status, VoiceCommandExecutionStatus.unmatched);
  });

  test('voice command api maps 404 to backend pending', () async {
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 404,
              data: <String, dynamic>{'message': 'Not Found'},
            ),
            type: DioExceptionType.badResponse,
            message: 'Not Found',
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    final result = await VoiceCommandApi.submit(
      text: '停止',
      commandType: VoiceCommandType.stop,
      confidence: 1,
    );

    expect(result.status, VoiceCommandExecutionStatus.backendPending);
  });

  test('elder help api sends voice trigger mode', () async {
    Map<String, dynamic>? capturedBody;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        capturedBody = Map<String, dynamic>.from(options.data as Map);
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'code': 0,
              'message': 'ok',
              'data': <String, dynamic>{
                'id': 9,
                'status': 'pending_revoke',
                'triggerTime': '2026-07-10T10:00:00Z',
              },
            },
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    await ElderHelpApi.createHelpRequest(triggerMode: 'voice');

    expect(capturedBody?['triggerMode'], 'voice');
  });

  testWidgets('home page contains a voice control entry', (tester) async {
    AuthSession.saveElderState(
      name: '张爷爷',
      phone: '13800000000',
      claimed: true,
      familyCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: ElderModuleRoutes.routes(),
        home: const ElderHomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('elder_voice_control_entry')),
        findsOneWidget);
  });

  testWidgets('voice control page records a matched command', (tester) async {
    final recognizer = _FakeRecognizerService(
      const VoiceRecognitionResult(transcript: '停止', usedMock: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElderVoiceControlPage(
          recognizerService: recognizer,
          executeMatchOverride: (VoiceCommandMatch match) async {
            return match.copyWith(
              status: VoiceCommandExecutionStatus.backendPending,
              detailMessage: '已识别，待后端接入',
            );
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('stop'), findsWidgets);
    expect(find.textContaining('停止'), findsWidgets);
  });
}

class _FakeRecognizerService extends VoiceCommandRecognizerService {
  _FakeRecognizerService(this._result);

  final VoiceRecognitionResult _result;

  @override
  Future<VoiceRecognitionResult> listenOnce({
    required void Function(String) onTranscript,
  }) async {
    onTranscript(_result.transcript);
    return _result;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
