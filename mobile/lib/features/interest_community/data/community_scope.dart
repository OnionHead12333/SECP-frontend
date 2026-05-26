import '../../../../core/auth/auth_session.dart';
import '../../child/models/child_local_models.dart';

/// 兴趣社群成员 scope：优先用手机号对齐老人端与子女端预览。
abstract final class CommunityScope {
  static String forCurrentElder() {
    final phone = AuthSession.elderPhone?.trim();
    if (phone != null && phone.isNotEmpty) return 'phone_$phone';
    final id = AuthSession.elderId;
    if (id != null) return 'elder_$id';
    return 'elder_local';
  }

  static String forBoundElder(BoundElder elder) {
    final phone = _extractPhone(elder.accountHint);
    if (phone != null) return 'phone_$phone';
    if (elder.id.isNotEmpty) return 'elder_${elder.id}';
    return 'elder_${elder.displayName}';
  }

  static String? _extractPhone(String? hint) {
    if (hint == null || hint.isEmpty) return null;
    final match = RegExp(r'1[3-9]\d{9}').firstMatch(hint);
    return match?.group(0);
  }

  /// 群聊列表/清空记录所归属的「查看者」scope（每人独立，互不影响）。
  static String chatViewerScopeForElder({String? membershipScopeKey}) {
    final phone = AuthSession.elderPhone?.trim();
    if (phone != null && phone.isNotEmpty) return 'phone_$phone';
    if (membershipScopeKey != null && membershipScopeKey.isNotEmpty) {
      return membershipScopeKey;
    }
    return forCurrentElder();
  }

  /// 子女端预览绑定老人某群时的查看者 scope（与老人本人清空记录分离）。
  static String chatViewerScopeForChildPreview(String elderScopeKey) {
    return 'child_preview_$elderScopeKey';
  }
}
