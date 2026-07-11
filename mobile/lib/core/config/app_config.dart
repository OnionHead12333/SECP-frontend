/// 与后端 [application.yml] 对齐：`server.servlet.context-path: /api`
///
/// 常用启动命令，后面可以直接复制：
///
/// 直接点运行到当前真机热点环境时，默认访问电脑 WLAN IPv4：
/// `http://172.20.10.3:8080/api`
///
/// 当前真机 + 电脑 WLAN IPv4：
/// `flutter run --dart-define=API_BASE=http://172.20.10.3:8080/api`
///
/// 其他环境备用地址（不用时保持注释）：
/// - Android 模拟器访问电脑本机后端：
///   `flutter run --dart-define=API_BASE=http://10.0.2.2:8080/api`
/// - Android 真机 + Windows 移动热点/共享网络网卡：
///   `flutter run --dart-define=API_BASE=http://192.168.137.1:8080/api`
/// - Flutter Windows 桌面端或电脑浏览器访问本机后端：
///   `flutter run -d windows --dart-define=API_BASE=http://localhost:8080/api`
///
/// 选择规则：
/// - 跑 Android 真机且后端在电脑：用电脑当前 WLAN IPv4，例如 `172.20.10.3`。
/// - 跑 Android 模拟器：用 `10.0.2.2`。
/// - 换 WiFi / 手机热点后 IP 可能变化，重新执行 `ipconfig`，看 WLAN 的 IPv4。
/// - 后端配置了 `/api` 上下文路径，所以这里保留 `/api`。
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.43.253:8080/api',
  );

  static const String inspectionApiBase = String.fromEnvironment(
    'INSPECTION_API_BASE',
    // Local backend for phone inspection testing.
    defaultValue: 'http://192.168.43.253:8080/api',
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

  /// 本机 / 模拟器调试语音撤回链路用：不调用系统 SpeechRecognizer，
  /// 在进入监听态后自动模拟识别到“撤回”。真实设备联调保持 false。
  static const bool useMockStt = bool.fromEnvironment(
    'USE_MOCK_STT',
    defaultValue: false,
  );

  static const String xfyunIatAppId =
      String.fromEnvironment('XFYUN_IAT_APP_ID');
  static const String xfyunIatApiKey =
      String.fromEnvironment('XFYUN_IAT_API_KEY');
  static const String xfyunIatApiSecret =
      String.fromEnvironment('XFYUN_IAT_API_SECRET');
  static const String xfyunIatHost = String.fromEnvironment(
    'XFYUN_IAT_HOST',
    defaultValue: 'iat-api.xfyun.cn',
  );
  static const String xfyunIatPath = String.fromEnvironment(
    'XFYUN_IAT_PATH',
    defaultValue: '/v2/iat',
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

  static const bool useMockInspection = bool.fromEnvironment(
    'USE_MOCK_INSPECTION',
    defaultValue: false,
  );
}
