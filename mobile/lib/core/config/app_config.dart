/// 与后端 [application.yml] 对齐：`server.servlet.context-path: /api`
///
/// 常用启动命令，后面可以直接复制：
///
/// 1. Android 模拟器访问电脑本机后端：
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:8080/api`
///
/// 2. Android 真机 + 电脑 WLAN 当前校园/局域网 IP：
/// `flutter run --dart-define=API_BASE=http://10.61.195.102:8080/api`
///
/// 3. Android 真机 + 手机热点时电脑旧 IP 示例：
/// `flutter run --dart-define=API_BASE=http://172.20.10.3:8080/api`
///
/// 4. Android 真机 + Windows 移动热点/共享网络网卡：
/// `flutter run --dart-define=API_BASE=http://192.168.137.1:8080/api`
///
/// 6. Flutter Windows 桌面端或电脑浏览器访问本机后端：
/// `flutter run -d windows --dart-define=API_BASE=http://localhost:8080/api`
///
/// 选择规则：
/// - 跑 Android 模拟器：用 `10.0.2.2`。
/// - 跑 USB 真机但后端在电脑：用电脑当前 WLAN IPv4，例如 `10.61.195.102`。
/// - 电脑连接手机热点后 IP 会变，重新执行 `ipconfig`，看 WLAN 的 IPv4。
/// - 后端配置了 `/api` 上下文路径，所以这里保留 `/api`。
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
    defaultValue: false,
  );

  /// 当前紧急联系人功能默认保留前端本地联调能力；
  /// 后端准备好后可通过 dart-define 切到真实接口。
  static const bool useMockEmergencyContacts = bool.fromEnvironment(
    'USE_MOCK_EMERGENCY_CONTACTS',
    defaultValue: false,
  );

  /// 当前没有开启后端、也还没接入树莓派蓝牙设备，
  /// 默认走本地 mock 轨迹，先把前端地图/轨迹/守护流程跑通。
  /// 后端联调时再通过 dart-define 切到真实定位链路。
  static const bool useMockLocation = bool.fromEnvironment(
    'USE_MOCK_LOCATION',
    defaultValue: false,
  );

  /// 喝水/用药/运动/外出提醒等接口后端未实现时，必须与「是否用真实高德」解耦：
  /// 否则 `USE_MOCK_LOCATION=false` 时会去请求不存在的 `/v1/elder/.../today-progress`，
  /// 服务端打出 `No static resource ...`，易误以为是 SOS 或子女登录问题。
  /// 需要联调真实提醒 API 时再 `--dart-define=USE_MOCK_REMINDERS=false`。
  static const bool useMockReminders = bool.fromEnvironment(
    'USE_MOCK_REMINDERS',
    defaultValue: true,
  );
}
