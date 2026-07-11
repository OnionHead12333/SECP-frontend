import 'package:dio/dio.dart';

import '../models/api_response.dart';
import '../network/api_client.dart';
import 'voice_command_models.dart';

abstract final class VoiceCommandApi {
  static Future<VoiceCommandSubmitResult> submit({
    required String text,
    required VoiceCommandType commandType,
    required double confidence,
  }) async {
    try {
      final response = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/voice/command',
        data: {
          'text': text,
          'cmd': commandType.backendValue,
          'confidence': confidence,
          'source': 'voice',
        },
      );
      final body = response.data;
      if (body == null) {
        return const VoiceCommandSubmitResult(
          status: VoiceCommandExecutionStatus.failed,
          message: '语音命令上报失败：空响应',
        );
      }
      final api = ApiResponse.fromJson(
        body,
        (raw) => raw is Map<String, dynamic> ? raw : null,
      );
      if (!api.isSuccess) {
        final message =
            api.displayMessage.isEmpty ? '语音命令上报失败' : api.displayMessage;
        if (_looksLikeBackendPending(message)) {
          return const VoiceCommandSubmitResult(
            status: VoiceCommandExecutionStatus.backendPending,
            message: '已识别，待后端接入',
          );
        }
        return VoiceCommandSubmitResult(
          status: VoiceCommandExecutionStatus.failed,
          message: message,
        );
      }
      return VoiceCommandSubmitResult(
        status: VoiceCommandExecutionStatus.executed,
        message: api.displayMessage.isEmpty ? '语音命令已执行' : api.displayMessage,
      );
    } on DioException catch (error) {
      final message = error.message ?? error.toString();
      if (_looksLikeBackendPending(message)) {
        return const VoiceCommandSubmitResult(
          status: VoiceCommandExecutionStatus.backendPending,
          message: '已识别，待后端接入',
        );
      }
      return VoiceCommandSubmitResult(
        status: VoiceCommandExecutionStatus.failed,
        message: message.isEmpty ? '语音命令上报失败' : message,
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (_looksLikeBackendPending(message)) {
        return const VoiceCommandSubmitResult(
          status: VoiceCommandExecutionStatus.backendPending,
          message: '已识别，待后端接入',
        );
      }
      return VoiceCommandSubmitResult(
        status: VoiceCommandExecutionStatus.failed,
        message: message.isEmpty ? '语音命令上报失败' : message,
      );
    }
  }

  static bool _looksLikeBackendPending(String message) {
    final lower = message.toLowerCase();
    return lower.contains('http 404') ||
        lower.contains('404') ||
        lower.contains('not found') ||
        lower.contains('no static resource') ||
        lower.contains('request method') ||
        lower.contains('暂未实现') ||
        lower.contains('待后端接入') ||
        lower.contains('unsupported');
  }
}
