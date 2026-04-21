import '../../../core/config/app_config.dart';
import '../models/elder_help_request.dart';
import 'elder_help_api.dart';
import 'elder_help_mock_service.dart';

final class ElderHelpService {
  ElderHelpService._();

  static Future<ElderHelpRequest> createHelpRequest() {
    if (AppConfig.useMockSos) {
      return ElderHelpMockService.createHelpRequest();
    }
    return ElderHelpApi.createHelpRequest();
  }

  static Future<ElderHelpRequest> revokeHelpRequest({
    required int alertId,
    required String cancelMode,
  }) {
    if (AppConfig.useMockSos) {
      return ElderHelpMockService.revokeHelpRequest(
        alertId: alertId,
        cancelMode: cancelMode,
      );
    }
    return ElderHelpApi.revokeHelpRequest(
      alertId: alertId,
      cancelMode: cancelMode,
    );
  }

  static Future<ElderHelpRequest> sendNow({required int alertId}) {
    if (AppConfig.useMockSos) {
      return ElderHelpMockService.sendNow(alertId: alertId);
    }
    return ElderHelpApi.sendNow(alertId: alertId);
  }

  static Future<ElderHelpRequest> getHelpRequestStatus({required int alertId}) {
    if (AppConfig.useMockSos) {
      return ElderHelpMockService.getHelpRequestStatus(alertId: alertId);
    }
    return ElderHelpApi.getHelpRequestStatus(alertId: alertId);
  }
}
