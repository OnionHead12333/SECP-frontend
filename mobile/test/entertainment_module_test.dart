import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_elderly_care_mobile/core/network/api_client.dart';
import 'package:smart_elderly_care_mobile/features/elder/elder_module_routes.dart';
import 'package:smart_elderly_care_mobile/features/elder/presentation/elder_home_page.dart';
import 'package:smart_elderly_care_mobile/features/entertainment/data/entertainment_api.dart';
import 'package:smart_elderly_care_mobile/features/entertainment/presentation/entertainment_page.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/employee_home_page.dart';

void main() {
  tearDown(() {
    EntertainmentApi.clearMockDataForTest();
  });

  test('entertainment API uses backend paths and command payloads', () async {
    final captured = <String, Object?>{};
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        captured[options.path] = options.data ?? true;
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: {
              'code': 0,
              'message': 'ok',
              'data': options.path.endsWith('/music')
                  ? [
                      {
                        'id': 7,
                        'musicName': '春日散步',
                        'artist': '护理中心',
                        'durationSeconds': 180,
                        'suitableScene': '午后放松',
                      }
                    ]
                  : options.path.endsWith('/tasks')
                      ? []
                      : {'taskId': 't1', 'status': 'sent'},
            },
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    final music = await EntertainmentApi.fetchMusic();
    await EntertainmentApi.playMusic(music.first);
    await EntertainmentApi.startDance(music.first, danceMode: 'happy');
    await EntertainmentApi.fetchTasks();
    await EntertainmentApi.fetchStatus();

    expect(
        captured.keys,
        containsAll([
          '/api/entertainment/music',
          '/api/entertainment/music/play',
          '/api/entertainment/dance/start',
          '/api/entertainment/tasks',
          '/api/entertainment/status',
        ]));
    expect(captured['/api/entertainment/music/play'],
        containsPair('musicName', '春日散步'));
    expect(captured['/api/entertainment/dance/start'],
        containsPair('danceMode', 'happy'));
  });

  testWidgets('entertainment page lists music and sends commands',
      (tester) async {
    EntertainmentApi.setMockDataForTest(
      music: [
        {
          'id': 1,
          'musicName': '晨间舒展',
          'artist': '康养乐队',
          'durationSeconds': 210,
          'suitableScene': '晨练',
        },
      ],
      tasks: [
        {
          'taskId': 'task-1',
          'musicName': '晨间舒展',
          'commandType': 'dance',
          'status': 'running',
          'danceMode': 'gentle',
        },
      ],
      status: {'taskId': 'task-1', 'status': 'running'},
    );

    await tester.pumpWidget(const MaterialApp(home: EntertainmentPage()));
    await tester.pumpAndSettle();

    expect(find.text('晨间舒展'), findsWidgets);
    expect(find.text('康养乐队'), findsOneWidget);
    expect(find.text('03:30'), findsOneWidget);
    expect(find.text('晨练'), findsOneWidget);
    expect(find.text('running'), findsWidgets);
    expect(find.text('播放音乐'), findsOneWidget);
    expect(find.text('播放并跳舞'), findsOneWidget);

    await tester.tap(find.text('播放音乐'));
    await tester.pump();
    expect(find.text('命令已发送'), findsOneWidget);

    await tester.tap(find.text('播放并跳舞'));
    await tester.pump();
    expect(find.text('跳舞命令已发送'), findsOneWidget);
  });

  testWidgets('employee and elder homes expose entertainment entry',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/employee/entertainment': (_) => const EntertainmentPage(),
        },
        home: const EmployeeHomePage(),
      ),
    );

    expect(find.text('巡检地图'), findsOneWidget);
    expect(find.text('娱乐'), findsOneWidget);

    SharedPreferences.setMockInitialValues(
      {'elder_login_permission_guide_shown_v1': true},
    );
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          ElderModuleRoutes.elderEntertainment: (_) =>
              const EntertainmentPage(),
        },
        home: const ElderHomePage(),
      ),
    );
    await tester.pump();

    expect(find.text('娱乐'), findsOneWidget);
  });
}
