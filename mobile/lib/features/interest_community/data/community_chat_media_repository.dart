import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 群聊图片（本机路径，接入后端前与语音文件同样存应用目录）。
abstract final class CommunityChatMediaRepository {
  static Future<String> saveImageFromFile({
    required String communityId,
    required String sourcePath,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/community_chat_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final ext = _extension(sourcePath);
    final name = '${DateTime.now().millisecondsSinceEpoch}_$communityId$ext';
    final target = File('${imageDir.path}/$name');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    if (ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp') {
      return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }
}
