import 'package:dio/dio.dart';

import 'remote_car_models.dart';

class ChildRemoteCarGatewayClient {
  ChildRemoteCarGatewayClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> sendCommand({
    required String gatewayBaseUrl,
    required RemoteCarCommand command,
  }) async {
    final url = _join(gatewayBaseUrl, '/api/command');
    await _dio.post<Map<String, dynamic>>(
      url,
      data: {'cmd': command.gatewayValue},
    );
  }

  Future<RosCarState> fetchState({required String gatewayBaseUrl}) async {
    final url = _join(gatewayBaseUrl, '/api/state');
    final response = await _dio.get<Object?>(url);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return RosCarState.fromJson(data);
    }
    if (data is Map) {
      return RosCarState.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Invalid ROS2 gateway state response');
  }

  static String _join(String base, String path) {
    final cleanBase = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanBase.isEmpty) {
      throw ArgumentError('gatewayBaseUrl is required');
    }
    return '$cleanBase$path';
  }
}
