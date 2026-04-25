/// 家庭绑定表中的子女（老人端展示）。
class ElderBoundChild {
  const ElderBoundChild({
    required this.childUserId,
    required this.name,
    required this.phone,
    required this.relation,
    required this.isPrimary,
  });

  final String childUserId;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  factory ElderBoundChild.fromJson(Map<String, dynamic> json) {
    return ElderBoundChild(
      childUserId: '${json['childUserId'] ?? json['child_user_id'] ?? ''}',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      relation: json['relation']?.toString() ?? '家人',
      isPrimary: json['isPrimary'] == true || json['is_primary'] == true,
    );
  }
}
