class ElderMockEmergencyContact {
  const ElderMockEmergencyContact({
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

  ElderMockEmergencyContact copyWith({
    String? id,
    String? name,
    String? relation,
    String? phone,
    bool? isPrimary,
    String? note,
  }) {
    return ElderMockEmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
      note: note ?? this.note,
    );
  }
}
