/// 注册时的用户类型，与后端约定字段 `role`。
enum RegisterUserRole {
  elder('elder', '老人'),
  child('child', '子女');

  const RegisterUserRole(this.apiValue, this.label);

  /// 提交给接口的值
  final String apiValue;

  final String label;
}
