/// 将后端返回的 message 转成适合普通用户阅读的文案，避免暴露 SQL/JDBC/栈信息。
String userFacingApiMessage(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '请求失败，请稍后重试';
  final lower = t.toLowerCase();
  if (t.contains('SQLSyntaxErrorException') ||
      t.contains("doesn't exist") ||
      t.contains('Unknown column') ||
      t.contains('Caused by:') ||
      t.contains('java.sql.') ||
      lower.contains('sqlexception') ||
      lower.contains('jdbc') ||
      lower.contains('hibernate') ||
      lower.contains('constraint ') ||
      t.contains('Table \'') ||
      (t.contains('references ') && lower.contains('foreign'))) {
    return '服务暂不可用，请稍后重试';
  }
  return t;
}
