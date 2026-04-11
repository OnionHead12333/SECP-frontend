/// 与后端 [application.yml] 对齐：`server.servlet.context-path: /api`
/// 模拟器访问本机后端请用 10.0.2.2；真机请改为电脑局域网 IP。
/// 构建示例：`flutter run --dart-define=API_BASE=http://192.168.1.10:8080/api`
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  static const String amapAndroidKey = String.fromEnvironment(
    'AMAP_ANDROID_KEY',
    defaultValue: 'YOUR_AMAP_ANDROID_KEY',
  );

  static const String amapIosKey = String.fromEnvironment(
    'AMAP_IOS_KEY',
    defaultValue: 'YOUR_AMAP_IOS_KEY',
  );

  /// 当前 SOS 功能默认保留前端本地联调能力；
  /// 后端准备好后可通过 dart-define 切到真实接口。
  static const bool useMockSos = bool.fromEnvironment(
    'USE_MOCK_SOS',
    defaultValue: true,
  );

  /// 定位功能默认走真实权限与自动上传链路；
  /// 如需继续本地演示，可通过 dart-define 切到 mock。
  static const bool useMockLocation = bool.fromEnvironment(
    'USE_MOCK_LOCATION',
    defaultValue: false,
  );
}
