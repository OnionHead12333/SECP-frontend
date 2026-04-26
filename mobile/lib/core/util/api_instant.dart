/// 解析后端 [java.time.Instant] 的 JSON 表示（与 Spring/Jackson 一致），并转为 **本机本地** [DateTime] 用于展示/倒计时。
///
/// 支持：ISO-8601 字符串（含/不含 `Z`）、毫秒/秒级整数时间戳。避免仅支持字符串时误用 [DateTime.now] 作回退导致「时间对不上」。
DateTime? parseApiInstantToLocal(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) {
    return raw.isUtc ? raw.toLocal() : raw;
  }
  if (raw is num) {
    final v = raw.toDouble();
    // 与 Spring Instant 时间戳（秒/毫秒）常见范围区分：合理「秒」值 < 1e10（到 2286 年量级）
    final int ms;
    if (v.abs() < 1e10) {
      ms = (v * 1000).round();
    } else {
      ms = v.round();
    }
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final t = DateTime.tryParse(s);
  if (t == null) return null;
  return t.isUtc ? t.toLocal() : t;
}
