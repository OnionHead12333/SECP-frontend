import 'package:dio/dio.dart';

class RobotControlBridgeClient {
  RobotControlBridgeClient({
    this.baseUrl = 'http://127.0.0.1:18080',
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final String baseUrl;
  final Dio _dio;

  Future<Map<String, dynamic>> publishInitialPose(
    Map<String, dynamic> pose,
  ) {
    return _postPose('/robot/navigation/initialpose', pose);
  }

  Future<Map<String, dynamic>> publishGoalPose(
    Map<String, dynamic> pose,
  ) {
    return _postPose('/robot/navigation/goal-pose', pose);
  }

  Future<Map<String, dynamic>> checkHealth() {
    return _get('/health');
  }

  Future<Map<String, dynamic>> startN1() {
    return _post('/robot/navigation/start-n1');
  }

  Future<Map<String, dynamic>> startN3() {
    return _post('/robot/navigation/start-n3');
  }

  Future<Map<String, dynamic>> prepareNavigation() {
    return _post('/robot/navigation/prepare');
  }

  Future<Map<String, dynamic>> restartNavigation() {
    return _post('/robot/navigation/restart');
  }

  Future<Map<String, dynamic>> emergencyStop() {
    return _post('/robot/navigation/emergency-stop');
  }

  Future<Map<String, dynamic>> checkNavigationReady() {
    return _get('/robot/navigation/ready');
  }

  Future<Map<String, dynamic>> loadNavigationPlan() {
    return _get('/robot/navigation/plan');
  }

  Future<Map<String, dynamic>> _postPose(
    String path,
    Map<String, dynamic> pose,
  ) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: {
          'x': _numberField(pose, 'x'),
          'y': _numberField(pose, 'y'),
          'yaw': _numberField(pose, 'yaw'),
        },
      );
      return _extractData(response);
    } on DioException catch (error) {
      throw StateError(_formatDioError(error));
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get<Object?>(path);
      return _extractData(response);
    } on DioException catch (error) {
      throw StateError(_formatDioError(error));
    }
  }

  Future<Map<String, dynamic>> _post(String path) async {
    try {
      final response = await _dio.post<Object?>(path);
      return _extractData(response);
    } on DioException catch (error) {
      throw StateError(_formatDioError(error));
    }
  }

  Map<String, dynamic> _extractData(Response<Object?> response) {
    final body = response.data;
    if (body is! Map) {
      throw StateError('Invalid robot bridge response');
    }
    final json = Map<String, dynamic>.from(body);
    final success = json['success'] as bool? ?? false;
    if (!success) {
      throw StateError('${json['message'] ?? 'robot bridge request failed'}');
    }
    final data = json['data'];
    if (data is! Map) {
      throw StateError('Robot bridge response has no data');
    }
    return Map<String, dynamic>.from(data);
  }

  String _formatDioError(DioException error) {
    final body = error.response?.data;
    if (body is Map) {
      final json = Map<String, dynamic>.from(body);
      final parts = <String>[
        '${json['message'] ?? 'robot bridge request failed'}',
      ];
      final data = json['data'];
      if (data is Map) {
        final details = _summarizeBridgeData(Map<String, dynamic>.from(data));
        if (details.isNotEmpty) parts.add(details);
      }
      return parts.join('\n');
    }
    return error.message ?? error.toString();
  }

  String _summarizeBridgeData(Map<String, dynamic> data) {
    final parts = <String>[];
    final ready = data['ready'];
    if (ready is Map) {
      final missing = ready['missingTopics'];
      if (missing is List && missing.isNotEmpty) {
        parts.add('Missing topics: ${missing.join(', ')}');
      }
      final topics = ready['topics'];
      if (topics is List && topics.isNotEmpty) {
        parts.add('Current topics: ${topics.join(', ')}');
      }
    }

    final logs = data['logs'];
    if (logs is Map) {
      final stdout = logs['stdout'];
      if (stdout is String && stdout.trim().isNotEmpty) {
        parts.add(_tail('Logs', stdout));
      }
    }

    final stderr = data['stderr'];
    if (stderr is String && stderr.trim().isNotEmpty) {
      parts.add(_tail('stderr', stderr));
    }
    final stdout = data['stdout'];
    if (stdout is String && stdout.trim().isNotEmpty) {
      parts.add(_tail('stdout', stdout));
    }
    return parts.join('\n');
  }

  String _tail(String label, String value) {
    final trimmed = value.trim();
    final tail = trimmed.length <= 1600
        ? trimmed
        : trimmed.substring(trimmed.length - 1600);
    return '$label:\n$tail';
  }

  double _numberField(Map<String, dynamic> pose, String key) {
    final value = pose[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('$value');
    if (parsed == null) {
      throw ArgumentError('$key must be a number');
    }
    return parsed;
  }
}
