import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

final class EntertainmentApi {
  EntertainmentApi._();

  static const String _base = '/api/entertainment';

  static List<Map<String, dynamic>>? _mockMusicForTest;
  static List<Map<String, dynamic>>? _mockTasksForTest;
  static Map<String, dynamic>? _mockStatusForTest;

  static Future<List<EntertainmentMusic>> fetchMusic() async {
    final mock = _mockMusicForTest;
    if (mock != null) {
      return mock.map(EntertainmentMusic.fromJson).toList(growable: false);
    }

    final res = await ApiClient.dio.get<Object?>('$_base/music');
    final payload = _payload(res.data);
    return _listPayload(payload)
        .whereType<Map>()
        .map((item) =>
            EntertainmentMusic.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<EntertainmentTaskStatus?> playMusic(
    EntertainmentMusic music,
  ) async {
    if (_mockMusicForTest != null) {
      _mockStatusForTest = {
        'taskId': 'mock-play-${music.id ?? music.musicName}',
        'musicName': music.musicName,
        'commandType': 'music',
        'status': 'sent',
      };
      return EntertainmentTaskStatus.fromJson(_mockStatusForTest!);
    }

    final res = await ApiClient.dio.post<Object?>(
      '$_base/music/play',
      data: music.commandPayload(),
    );
    final payload = _payload(res.data);
    return payload is Map
        ? EntertainmentTaskStatus.fromJson(Map<String, dynamic>.from(payload))
        : null;
  }

  static Future<EntertainmentTaskStatus?> startDance(
    EntertainmentMusic music, {
    required String danceMode,
  }) async {
    if (_mockMusicForTest != null) {
      _mockStatusForTest = {
        'taskId': 'mock-dance-${music.id ?? music.musicName}',
        'musicName': music.musicName,
        'commandType': 'dance',
        'status': 'sent',
        'danceMode': danceMode,
      };
      return EntertainmentTaskStatus.fromJson(_mockStatusForTest!);
    }

    final res = await ApiClient.dio.post<Object?>(
      '$_base/dance/start',
      data: {
        ...music.commandPayload(),
        'danceMode': danceMode,
      },
    );
    final payload = _payload(res.data);
    return payload is Map
        ? EntertainmentTaskStatus.fromJson(Map<String, dynamic>.from(payload))
        : null;
  }

  static Future<EntertainmentTaskStatus?> stopDance(String taskId) async {
    if (_mockMusicForTest != null) {
      _mockStatusForTest = {
        'taskId': taskId,
        'commandType': 'dance',
        'status': 'cancelled',
        'feedback': '已停止',
      };
      return EntertainmentTaskStatus.fromJson(_mockStatusForTest!);
    }

    final res = await ApiClient.dio.post<Object?>(
      '$_base/dance/stop',
      data: {'taskId': _taskIdPayloadValue(taskId)},
    );
    final payload = _payload(res.data);
    return payload is Map
        ? EntertainmentTaskStatus.fromJson(Map<String, dynamic>.from(payload))
        : null;
  }

  static Future<List<EntertainmentTaskStatus>> fetchTasks() async {
    final mock = _mockTasksForTest;
    if (mock != null) {
      return mock.map(EntertainmentTaskStatus.fromJson).toList(growable: false);
    }

    final res = await ApiClient.dio.get<Object?>('$_base/tasks');
    final payload = _payload(res.data);
    return _listPayload(payload)
        .whereType<Map>()
        .map((item) =>
            EntertainmentTaskStatus.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<EntertainmentTaskStatus?> fetchStatus() async {
    final mock = _mockStatusForTest;
    if (mock != null) return EntertainmentTaskStatus.fromJson(mock);

    final res = await ApiClient.dio.get<Object?>('$_base/status');
    final payload = _payload(res.data);
    return payload is Map
        ? EntertainmentTaskStatus.fromJson(Map<String, dynamic>.from(payload))
        : null;
  }

  static void setMockDataForTest({
    required List<Map<String, dynamic>> music,
    required List<Map<String, dynamic>> tasks,
    required Map<String, dynamic>? status,
  }) {
    _mockMusicForTest = music;
    _mockTasksForTest = tasks;
    _mockStatusForTest = status;
  }

  static void clearMockDataForTest() {
    _mockMusicForTest = null;
    _mockTasksForTest = null;
    _mockStatusForTest = null;
  }

  static Object? _payload(Object? body) {
    if (body is Map<String, dynamic>) {
      final api = ApiResponse.fromJson(body, (raw) => raw);
      if (api.code != -1) {
        if (!api.isSuccess) throw Exception(api.displayMessage);
        return api.data;
      }
    }
    if (body is Map) {
      if (body.containsKey('data')) return body['data'];
      return body;
    }
    return body;
  }

  static List<Object?> _listPayload(Object? payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final list = payload['list'] ?? payload['records'] ?? payload['items'];
      if (list is List) return list;
    }
    throw StateError('Invalid entertainment list response');
  }
}

final class EntertainmentMusic {
  const EntertainmentMusic({
    this.id,
    required this.musicName,
    required this.artist,
    required this.durationSeconds,
    required this.suitableScene,
  });

  final Object? id;
  final String musicName;
  final String artist;
  final int durationSeconds;
  final String suitableScene;

  factory EntertainmentMusic.fromJson(Map<String, dynamic> json) {
    return EntertainmentMusic(
      id: json['id'] ?? json['musicId'],
      musicName: _text(json['musicName'] ?? json['name'], fallback: '未命名音乐'),
      artist: _text(json['artist'], fallback: '未知艺术家'),
      durationSeconds:
          _int(json['durationSeconds'] ?? json['duration'], fallback: 0),
      suitableScene: _text(json['suitableScene'], fallback: '日常娱乐'),
    );
  }

  Map<String, Object?> commandPayload() {
    return {
      if (id != null) 'musicId': id,
      'musicName': musicName,
    };
  }
}

final class EntertainmentTaskStatus {
  const EntertainmentTaskStatus({
    this.taskId,
    this.musicName,
    this.commandType,
    required this.status,
    this.danceMode,
    this.message,
  });

  final String? taskId;
  final String? musicName;
  final String? commandType;
  final String status;
  final String? danceMode;
  final String? message;

  factory EntertainmentTaskStatus.fromJson(Map<String, dynamic> json) {
    return EntertainmentTaskStatus(
      taskId: _nullableText(json['taskId'] ?? json['id']),
      musicName: _nullableText(json['musicName']),
      commandType: _nullableText(json['commandType'] ?? json['type']),
      status: _text(json['status'], fallback: 'pending'),
      danceMode: _nullableText(json['danceMode']),
      message: _nullableText(
        json['feedback'] ?? json['message'] ?? json['description'],
      ),
    );
  }
}

String _text(Object? value, {required String fallback}) {
  final text = _nullableText(value);
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

Object _taskIdPayloadValue(String taskId) {
  return int.tryParse(taskId) ?? taskId;
}
