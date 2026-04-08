import '../models/elder_mock_family_member.dart';
import '../models/elder_mock_recognition_result.dart';

/// 老人端注册绑定流程当前使用的本地模拟数据。
///
/// 说明：
/// - 用于没有数据库、没有后端完整接口时的页面联调与流程演示
/// - 仅供老人端当前开发阶段使用
final class ElderMockAuthService {
  ElderMockAuthService._();

  static const String mockPassword = '123456';

  static Future<String> login({
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final normalized = phone.trim();
    if (normalized.length != 11) {
      throw Exception('请输入 11 位手机号');
    }
    if (password != mockPassword) {
      throw Exception('模拟环境密码固定为 123456');
    }
    return 'elder-mock-token-$normalized';
  }

  static Future<void> register({
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final normalized = phone.trim();
    if (normalized.length != 11) {
      throw Exception('请输入 11 位手机号');
    }
    if (password.length < 6) {
      throw Exception('密码至少 6 位');
    }
  }

  static Future<ElderMockRecognitionResult> recognizeByPhone(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalized = phone.trim();
    if (normalized == '13800138001') {
      return const ElderMockRecognitionResult(
        hasExistingProfile: true,
        elderName: '张建国',
        phone: '13800138001',
        familyCount: 1,
      );
    }
    if (normalized == '13800138002') {
      return const ElderMockRecognitionResult(
        hasExistingProfile: true,
        elderName: '李秀英',
        phone: '13800138002',
        familyCount: 2,
      );
    }
    if (normalized == '13800138111') {
      return const ElderMockRecognitionResult(
        hasExistingProfile: false,
        elderName: '赵美兰',
        phone: '13800138111',
        familyCount: 0,
      );
    }
    return ElderMockRecognitionResult(
      hasExistingProfile: false,
      elderName: '老人用户',
      phone: normalized,
      familyCount: 0,
    );
  }

  static Future<ElderMockRecognitionResult> claimProfile(ElderMockRecognitionResult target) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return target.copyWith(hasExistingProfile: true);
  }

  static Future<ElderMockRecognitionResult> createIndependentProfile(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (phone.trim() == '13800138111') {
      return const ElderMockRecognitionResult(
        hasExistingProfile: false,
        elderName: '赵美兰',
        phone: '13800138111',
        familyCount: 0,
      );
    }
    return ElderMockRecognitionResult(
      hasExistingProfile: false,
      elderName: '老人用户',
      phone: phone.trim(),
      familyCount: 0,
    );
  }

  static int mockFamilyCountForLogin(String phone) {
    return familyMembersForPhone(phone).length;
  }

  static List<ElderMockFamilyMember> familyMembersForPhone(String phone) {
    switch (phone.trim()) {
      case '13800138001':
        return const [
          ElderMockFamilyMember(
            name: '张丽',
            relation: '女儿',
            phone: '13911112222',
            isPrimary: true,
          ),
        ];
      case '13800138002':
        return const [
          ElderMockFamilyMember(
            name: '王强',
            relation: '儿子',
            phone: '13933334444',
            isPrimary: true,
          ),
          ElderMockFamilyMember(
            name: '陈敏',
            relation: '女儿',
            phone: '13955556666',
            isPrimary: false,
          ),
        ];
      default:
        return const [];
    }
  }
}
