import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/device_status_snapshot.dart';

final class ChildDeviceApi {
  ChildDeviceApi._();

  static Future<List<DeviceStatusSnapshot>> listForElder(int elderId) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/child/elders/$elderId/devices',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) {
        if (raw is! List) return <Map<String, dynamic>>[];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
    if (!api.isSuccess) throw Exception(api.displayMessage);
    final list = api.data ?? const <Map<String, dynamic>>[];
    return list
        .map(DeviceStatusSnapshot.fromJson)
        .where((e) => e.deviceId.isNotEmpty)
        .toList();
  }
}
