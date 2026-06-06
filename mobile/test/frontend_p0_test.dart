import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/models/api_response.dart';
import 'package:smart_elderly_care_mobile/core/util/api_instant.dart';
import 'package:smart_elderly_care_mobile/core/util/api_user_message.dart';
import 'package:smart_elderly_care_mobile/features/child/data/child_api_error_text.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_bound_child.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_exercise_progress.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_location_point.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_medicine_progress.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_water_progress.dart';

void main() {
  group('TC-FE-01~04 ApiResponse 与用户提示', () {
    test('TC-FE-01 ApiResponse 能解析成功响应和 data', () {
      final response = ApiResponse<Map<String, dynamic>>.fromJson(
        {
          'code': 0,
          'message': 'ok',
          'data': {'token': 'demo-token'},
        },
        (json) => json! as Map<String, dynamic>,
      );

      expect(response.isSuccess, isTrue);
      expect(response.message, 'ok');
      expect(response.data?['token'], 'demo-token');
    });

    test('TC-FE-02 ApiResponse 能兼容字符串 code', () {
      final response = ApiResponse<Object?>.fromJson(
        {'code': '401', 'message': 'unauthorized'},
        null,
      );

      expect(response.code, 401);
      expect(response.isSuccess, isFalse);
    });

    test('TC-FE-03 空后端 message 会转换成默认用户提示', () {
      expect(userFacingApiMessage(''), '请求失败，请稍后重试');
      expect(userFacingApiMessage(null), '请求失败，请稍后重试');
    });

    test('TC-FE-04 SQL/JDBC 细节不会直接展示给用户', () {
      final response = ApiResponse<Object?>.fromJson(
        {
          'code': 500,
          'message':
              "SQLSyntaxErrorException: Table 'elder.user' doesn't exist",
        },
        null,
      );

      expect(response.displayMessage, '服务暂不可用，请稍后重试');
    });
  });

  group('TC-FE-05~08 后端时间解析', () {
    test('TC-FE-05 能解析 ISO-8601 UTC 时间', () {
      final value = parseApiInstantToLocal('2026-06-06T10:20:30Z');

      expect(value, isNotNull);
      expect(value!.toUtc().year, 2026);
      expect(value.toUtc().minute, 20);
    });

    test('TC-FE-06 能解析秒级时间戳', () {
      final value = parseApiInstantToLocal(1710000000);

      expect(value, isNotNull);
      expect(value!.toUtc().millisecondsSinceEpoch, 1710000000000);
    });

    test('TC-FE-07 能解析毫秒级时间戳', () {
      final value = parseApiInstantToLocal(1710000000123);

      expect(value, isNotNull);
      expect(value!.toUtc().millisecondsSinceEpoch, 1710000000123);
    });

    test('TC-FE-08 非法时间返回 null', () {
      expect(parseApiInstantToLocal('not-a-time'), isNull);
      expect(parseApiInstantToLocal(null), isNull);
    });
  });

  group('TC-FE-09~14 子女端接口错误提示', () {
    test('TC-FE-09 HTTP 401 会提示未授权', () {
      final text = describeChildApiError(_dioError(statusCode: 401));

      expect(text, contains('未授权'));
      expect(text, contains('HTTP 401'));
    });

    test('TC-FE-10 HTTP 403 会提示无访问权限', () {
      final text = describeChildApiError(_dioError(statusCode: 403));

      expect(text, contains('无访问权限'));
      expect(text, contains('HTTP 403'));
    });

    test('TC-FE-11 HTTP 404 会提示未找到', () {
      final text = describeChildApiError(_dioError(statusCode: 404));

      expect(text, contains('未找到'));
      expect(text, contains('HTTP 404'));
    });

    test('TC-FE-12 HTTP 500 会提示服务器错误', () {
      final text = describeChildApiError(_dioError(statusCode: 500));

      expect(text, contains('服务器错误'));
      expect(text, contains('HTTP 500'));
    });

    test('TC-FE-13 连接超时会提示检查网络互通', () {
      final text = describeChildApiError(
        DioException(
          requestOptions: RequestOptions(path: '/children'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(text, contains('连接超时'));
      expect(text, contains('网络互通'));
    });

    test('TC-FE-14 业务错误 message 会作为服务端提示展示', () {
      final text = describeChildApiError(
        _dioError(
          statusCode: 400,
          data: {'message': '老人尚未绑定'},
        ),
      );

      expect(text, '服务端：老人尚未绑定');
    });
  });

  group('TC-FE-15~20 老人端模型解析', () {
    test('TC-FE-15 ElderWaterProgress 能解析进度和时间', () {
      final progress = ElderWaterProgress.fromJson({
        'plannedCount': 8,
        'confirmedCount': 3,
        'missedCount': 1,
        'pendingCount': 4,
        'completionPercent': 37.5,
        'activeReminderId': 12,
        'lastConfirmedAt': '2026-06-06T08:30:00Z',
      });

      expect(progress.plannedCount, 8);
      expect(progress.confirmedCount, 3);
      expect(progress.completionPercent, 37.5);
      expect(progress.activeReminderId, 12);
      expect(progress.lastConfirmedAt, isNotNull);
    });

    test('TC-FE-16 ElderMedicineProgress 缺省字段有安全默认值', () {
      final progress = ElderMedicineProgress.fromJson({});

      expect(progress.plannedCount, 0);
      expect(progress.medicineName, '-');
      expect(progress.activeReminderId, 0);
    });

    test('TC-FE-17 ElderExerciseProgress copyWith 保留未修改字段', () {
      final progress = ElderExerciseProgress.fromJson({
        'plannedCount': 2,
        'completedCount': 1,
        'lastCompletionStatus': 'done',
        'lastCompletionSource': 'sensor',
      });

      final updated = progress.copyWith(pendingCount: 1);

      expect(updated.plannedCount, 2);
      expect(updated.completedCount, 1);
      expect(updated.pendingCount, 1);
      expect(updated.lastCompletionSource, 'sensor');
    });

    test('TC-FE-18 ElderBoundChild 兼容驼峰和下划线字段', () {
      final child = ElderBoundChild.fromJson({
        'child_user_id': 9,
        'name': '家属A',
        'phone': '138****7809',
        'is_primary': true,
      });

      expect(child.childUserId, '9');
      expect(child.name, '家属A');
      expect(child.relation, '家人');
      expect(child.isPrimary, isTrue);
    });

    test('TC-FE-19 ElderLocationPoint copyWith 能更新上传状态', () {
      final point = ElderLocationPoint(
        latitude: 39.9,
        longitude: 116.4,
        label: '家',
        recordedAt: DateTime(2026, 6, 6, 9),
        isHome: true,
      );

      final uploaded = point.copyWith(uploaded: true);

      expect(uploaded.latitude, 39.9);
      expect(uploaded.label, '家');
      expect(uploaded.uploaded, isTrue);
    });
  });
}

DioException _dioError({
  required int statusCode,
  Object? data,
}) {
  final requestOptions = RequestOptions(path: '/children');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Object?>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: data,
    ),
  );
}
