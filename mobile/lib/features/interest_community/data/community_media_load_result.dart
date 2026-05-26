import 'dart:typed_data';

/// 群聊图片/语音按需加载结果。
sealed class CommunityMediaLoadResult {
  const CommunityMediaLoadResult();
}

final class CommunityMediaLoading extends CommunityMediaLoadResult {
  const CommunityMediaLoading();
}

final class CommunityMediaReady extends CommunityMediaLoadResult {
  const CommunityMediaReady({
    this.bytes,
    this.filePath,
  });

  final Uint8List? bytes;
  final String? filePath;
}

final class CommunityMediaUnavailable extends CommunityMediaLoadResult {
  const CommunityMediaUnavailable([this.message = '媒体不可用']);

  final String message;
}
