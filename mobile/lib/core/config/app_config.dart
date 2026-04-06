/// 与后端 [application.yml] 对齐：`server.servlet.context-path: /api`
/// 模拟器访问本机后端请用 10.0.2.2；真机请改为电脑局域网 IP。
/// 构建示例：`flutter run --dart-define=API_BASE=http://192.168.1.10:8080/api`
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8080/api',
  );
}
