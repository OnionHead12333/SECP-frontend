class ElderMockRecognitionResult {
  const ElderMockRecognitionResult({
    required this.hasExistingProfile,
    required this.elderName,
    required this.phone,
    required this.familyCount,
  });

  final bool hasExistingProfile;
  final String elderName;
  final String phone;
  final int familyCount;

  ElderMockRecognitionResult copyWith({
    bool? hasExistingProfile,
    String? elderName,
    String? phone,
    int? familyCount,
  }) {
    return ElderMockRecognitionResult(
      hasExistingProfile: hasExistingProfile ?? this.hasExistingProfile,
      elderName: elderName ?? this.elderName,
      phone: phone ?? this.phone,
      familyCount: familyCount ?? this.familyCount,
    );
  }
}
