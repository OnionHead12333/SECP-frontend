class RecommendedDepartment {
  RecommendedDepartment({
    required this.departmentId,
    required this.departmentName,
    required this.reason,
  });

  final int? departmentId;
  final String departmentName;
  final String reason;

  factory RecommendedDepartment.fromJson(Map<String, dynamic> json) {
    return RecommendedDepartment(
      departmentId: _pickInt(json, const ['departmentId', 'department_id', 'id']),
      departmentName:
          _pickString(json, const ['departmentName', 'department_name', 'name']),
      reason: _pickString(json, const ['reason', 'recommendReason', 'description']),
    );
  }
}

class MatchedQa {
  MatchedQa({
    required this.question,
    required this.answer,
    required this.similarity,
  });

  final String question;
  final String answer;
  final double? similarity;

  factory MatchedQa.fromJson(Map<String, dynamic> json) {
    return MatchedQa(
      question: _pickString(json, const ['question', 'title']),
      answer: _pickString(json, const ['answer', 'content']),
      similarity: _pickDouble(json, const ['similarity', 'score']),
    );
  }
}

class AiConsultationResponse {
  AiConsultationResponse({
    required this.consultationId,
    required this.symptomType,
    required this.riskLevel,
    required this.needMedicalVisit,
    required this.needFamilyNotify,
    required this.finalAnswer,
    required this.recommendedDepartments,
    required this.matchedQaList,
    required this.followUpQuestion,
    required this.safetyNotice,
    required this.status,
  });

  final int? consultationId;
  final String symptomType;
  final String riskLevel;
  final bool needMedicalVisit;
  final bool needFamilyNotify;
  final String finalAnswer;
  final List<RecommendedDepartment> recommendedDepartments;
  final List<MatchedQa> matchedQaList;
  final String? followUpQuestion;
  final String safetyNotice;
  final String status;

  factory AiConsultationResponse.fromJson(Map<String, dynamic> json) {
    return AiConsultationResponse(
      consultationId: _pickInt(
        json,
        const ['consultationId', 'consultation_id', 'id'],
      ),
      symptomType: _pickString(
        json,
        const ['symptomType', 'symptom_type'],
        fallback: 'unknown',
      ),
      riskLevel: _pickString(
        json,
        const ['riskLevel', 'risk_level'],
        fallback: 'low',
      ),
      needMedicalVisit: _pickBool(
        json,
        const ['needMedicalVisit', 'need_medical_visit'],
      ),
      needFamilyNotify: _pickBool(
        json,
        const ['needFamilyNotify', 'need_family_notify'],
      ),
      finalAnswer: _pickString(
        json,
        const ['finalAnswer', 'final_answer', 'answer'],
      ),
      recommendedDepartments: _pickListMap(
        json,
        const ['recommendedDepartments', 'recommended_departments'],
      ).map(RecommendedDepartment.fromJson).toList(),
      matchedQaList: _pickListMap(
        json,
        const ['matchedQaList', 'matched_qa_list', 'matchedQa'],
      ).map(MatchedQa.fromJson).toList(),
      followUpQuestion: _pickNullableString(
        json,
        const ['followUpQuestion', 'follow_up_question'],
      ),
      safetyNotice: _pickString(
        json,
        const ['safetyNotice', 'safety_notice'],
      ),
      status: _pickString(json, const ['status'], fallback: 'processing'),
    );
  }
}

class AiConsultationDetail extends AiConsultationResponse {
  AiConsultationDetail({
    required super.consultationId,
    required this.elderlyId,
    required this.inputText,
    required this.inputType,
    required super.symptomType,
    required super.riskLevel,
    required super.needMedicalVisit,
    required super.needFamilyNotify,
    required super.finalAnswer,
    required super.recommendedDepartments,
    required super.matchedQaList,
    required super.followUpQuestion,
    required super.safetyNotice,
    required super.status,
    required this.createdAt,
  });

  final int? elderlyId;
  final String inputText;
  final String inputType;
  final String? createdAt;

  factory AiConsultationDetail.fromJson(Map<String, dynamic> json) {
    final base = AiConsultationResponse.fromJson(json);
    return AiConsultationDetail(
      consultationId: base.consultationId,
      elderlyId: _pickInt(json, const ['elderlyId', 'elderly_id']),
      inputText: _pickString(json, const ['inputText', 'input_text']),
      inputType: _pickString(
        json,
        const ['inputType', 'input_type'],
        fallback: 'text',
      ),
      symptomType: base.symptomType,
      riskLevel: base.riskLevel,
      needMedicalVisit: base.needMedicalVisit,
      needFamilyNotify: base.needFamilyNotify,
      finalAnswer: base.finalAnswer,
      recommendedDepartments: base.recommendedDepartments,
      matchedQaList: base.matchedQaList,
      followUpQuestion: base.followUpQuestion,
      safetyNotice: base.safetyNotice,
      status: base.status,
      createdAt: _pickNullableString(json, const ['createdAt', 'created_at']),
    );
  }
}

class AiConsultationHistoryItem {
  AiConsultationHistoryItem({
    required this.consultationId,
    required this.createdAt,
    required this.inputText,
    required this.riskLevel,
    required this.needMedicalVisit,
    required this.needFamilyNotify,
    required this.recommendedDepartments,
    required this.status,
  });

  final int? consultationId;
  final String createdAt;
  final String inputText;
  final String riskLevel;
  final bool needMedicalVisit;
  final bool needFamilyNotify;
  final List<RecommendedDepartment> recommendedDepartments;
  final String status;

  factory AiConsultationHistoryItem.fromJson(Map<String, dynamic> json) {
    return AiConsultationHistoryItem(
      consultationId: _pickInt(
        json,
        const ['consultationId', 'consultation_id', 'id'],
      ),
      createdAt: _pickString(json, const ['createdAt', 'created_at']),
      inputText: _pickString(
        json,
        const ['inputText', 'input_text', 'summary', 'chiefComplaint'],
      ),
      riskLevel: _pickString(
        json,
        const ['riskLevel', 'risk_level'],
        fallback: 'low',
      ),
      needMedicalVisit: _pickBool(
        json,
        const ['needMedicalVisit', 'need_medical_visit'],
      ),
      needFamilyNotify: _pickBool(
        json,
        const ['needFamilyNotify', 'need_family_notify'],
      ),
      recommendedDepartments: _pickListMap(
        json,
        const ['recommendedDepartments', 'recommended_departments'],
      ).map(RecommendedDepartment.fromJson).toList(),
      status: _pickString(json, const ['status'], fallback: 'processing'),
    );
  }
}

class AiFeedbackRequestModel {
  AiFeedbackRequestModel({
    required this.feedbackType,
    required this.feedbackText,
    required this.isHelpful,
    required this.hasVisitedDoctor,
  });

  final String feedbackType;
  final String feedbackText;
  final bool isHelpful;
  final bool hasVisitedDoctor;

  Map<String, dynamic> toJson() {
    return {
      'feedbackType': feedbackType,
      'feedbackText': feedbackText,
      'isHelpful': isHelpful,
      'hasVisitedDoctor': hasVisitedDoctor,
    };
  }
}

class AiNotifyFamilyResponse {
  AiNotifyFamilyResponse({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  factory AiNotifyFamilyResponse.fromJson(Map<String, dynamic> json) {
    return AiNotifyFamilyResponse(
      success: _pickBool(json, const ['success']),
      message: _pickString(json, const ['message']),
    );
  }
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String? _pickNullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _pickString(json, keys);
  return value.isEmpty ? null : value;
}

int? _pickInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _pickDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool _pickBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }
  return false;
}

List<Map<String, dynamic>> _pickListMap(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is! List) continue;
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}
