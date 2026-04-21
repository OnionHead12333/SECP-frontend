class ElderEmergencyContact {
  const ElderEmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.isPrimary,
    required this.note,
  });

  final String id;
  final String name;
  final String relation;
  final String phone;
  final bool isPrimary;
  final String note;

  ElderEmergencyContact copyWith({
    String? id,
    String? name,
    String? relation,
    String? phone,
    bool? isPrimary,
    String? note,
  }) {
    return ElderEmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
      note: note ?? this.note,
    );
  }

  factory ElderEmergencyContact.fromJson(Map<String, dynamic> json) {
    final priority = (json['priority'] as num?)?.toInt() ?? 1;
    final isPrimary = json['isPrimary'] == true || priority == 1;
    return ElderEmergencyContact(
      id: (json['contactId'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      relation: json['relation']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isPrimary: isPrimary,
      note: json['note']?.toString() ?? json['remark']?.toString() ?? '',
    );
  }
}
