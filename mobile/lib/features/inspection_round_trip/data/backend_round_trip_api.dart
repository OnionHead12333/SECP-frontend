import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/round_trip_backend_models.dart';

abstract interface class BackendRoundTripApi {
  Future<void> setInitialPose({
    required int robotId,
    required RoundTripMapPayload map,
    required RoundTripPosePayload pose,
    required String clientRequestId,
  });

  Future<BackendRoundTripTaskSnapshot> createRoundTrip({
    required int robotId,
    required RoundTripSubmission submission,
  });

  Future<BackendRoundTripTaskSnapshot> loadTask({
    required int robotId,
    required String taskId,
  });

  Future<BackendRoundTripTaskSnapshot> stopTask({
    required int robotId,
    required String taskId,
    required String clientRequestId,
  });
}

class DioBackendRoundTripApi implements BackendRoundTripApi {
  DioBackendRoundTripApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  @override
  Future<void> setInitialPose({
    required int robotId,
    required RoundTripMapPayload map,
    required RoundTripPosePayload pose,
    required String clientRequestId,
  }) async {
    await _dio.post<Object?>(
      '/v1/robots/$robotId/initial-pose',
      data: {
        'clientRequestId': clientRequestId,
        'mapId': map.mapId,
        'mapRevision': map.mapRevision,
        'pose': pose.toJson(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
      options: Options(headers: {'Idempotency-Key': clientRequestId}),
    );
  }

  @override
  Future<BackendRoundTripTaskSnapshot> createRoundTrip({
    required int robotId,
    required RoundTripSubmission submission,
  }) async {
    final response = await _dio.post<Object?>(
      '/v1/robots/$robotId/navigation/round-trips',
      data: submission.toJson(),
      options: Options(
        headers: {'Idempotency-Key': submission.clientRequestId},
      ),
    );
    return BackendRoundTripTaskSnapshot.fromJson(_extractData(response.data));
  }

  @override
  Future<BackendRoundTripTaskSnapshot> loadTask({
    required int robotId,
    required String taskId,
  }) async {
    final response = await _dio.get<Object?>(
      '/v1/robots/$robotId/navigation/tasks/$taskId',
    );
    return BackendRoundTripTaskSnapshot.fromJson(_extractData(response.data));
  }

  @override
  Future<BackendRoundTripTaskSnapshot> stopTask({
    required int robotId,
    required String taskId,
    required String clientRequestId,
  }) async {
    final response = await _dio.post<Object?>(
      '/v1/robots/$robotId/navigation/tasks/$taskId/stop',
      data: {'clientRequestId': clientRequestId},
      options: Options(headers: {'Idempotency-Key': clientRequestId}),
    );
    return BackendRoundTripTaskSnapshot.fromJson(_extractData(response.data));
  }

  Map<String, dynamic> _extractData(Object? body) {
    if (body is! Map) {
      throw StateError('后端返回了无效的往返任务响应。');
    }
    final json = Map<String, dynamic>.from(body);
    final success = json['success'];
    if (success == false) {
      throw StateError('${json['message'] ?? '后端往返任务请求失败'}');
    }
    final data = json.containsKey('data') ? json['data'] : json;
    if (data is! Map) {
      throw StateError('后端响应中缺少任务数据。');
    }
    return Map<String, dynamic>.from(data);
  }
}
