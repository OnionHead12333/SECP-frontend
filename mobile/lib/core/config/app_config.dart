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
    defaultValue: '84f7b71fbfea73f06252e2b06685934c',
  );

  static const String amapIosKey = String.fromEnvironment(
    'AMAP_IOS_KEY',
    defaultValue: 'e7a0de323ff973f1a7fc2c85f3670e66',
  );

  /// 当前 SOS 功能默认保留前端本地联调能力；
  /// 后端准备好后可通过 dart-define 切到真实接口。
  static const bool useMockSos = bool.fromEnvironment(
    'USE_MOCK_SOS',
    defaultValue: true,
  );

  /// 当前紧急联系人功能默认保留前端本地联调能力；
  /// 后端准备好后可通过 dart-define 切到真实接口。
  static const bool useMockEmergencyContacts = bool.fromEnvironment(
    'USE_MOCK_EMERGENCY_CONTACTS',
    defaultValue: true,
  );

  /// 当前没有开启后端、也还没接入树莓派蓝牙设备，
  /// 默认走本地 mock 轨迹，先把前端地图/轨迹/守护流程跑通。
  /// 后端联调时再通过 dart-define 切到真实定位链路。
  static const bool useMockLocation = bool.fromEnvironment(
    'USE_MOCK_LOCATION',
    defaultValue: true,
  );
}
