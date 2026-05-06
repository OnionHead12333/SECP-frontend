import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// 与后端 [DocumentClassItem] 对齐。
final class DocumentClassItem {
  const DocumentClassItem({
    required this.type,
    this.probability,
  });

  final String type;
  final double? probability;

  static DocumentClassItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final type = m['type'] as String? ?? '';
    final p = m['probability'];
    double? prob;
    if (p is num) prob = p.toDouble();
    return DocumentClassItem(type: type.isEmpty ? '未知' : type, probability: prob);
  }
}

/// 与后端 [MedicalOcrView] 对齐。
final class MedicalOcrResult {
  MedicalOcrResult({
    required this.fullText,
    this.raw,
    this.documentClasses,
    this.classifyRaw,
    this.routedSpecializedApi,
    this.specializedRaw,
    this.classificationWarning,
    this.structuredRouteSource,
  });

  final String fullText;
  final Map<String, dynamic>? raw;
  final List<DocumentClassItem>? documentClasses;
  final Map<String, dynamic>? classifyRaw;
  /// 后端根据分类路由的百度云结构化接口 id，如 medical_prescription
  final String? routedSpecializedApi;
  final Map<String, dynamic>? specializedRaw;
  /// 全文与云端文档分类明显不符时的提示；未命中全文关键词路由时可能因此不调用结构化接口
  final String? classificationWarning;
  /// keyword_text | doc_classify | null
  final String? structuredRouteSource;

  /// 按置信度优先的主分类（供 UI 摘要）。
  DocumentClassItem? get primaryClass {
    final list = documentClasses;
    if (list == null || list.isEmpty) return null;
    final sorted = [...list]..sort((a, b) {
        final pa = a.probability ?? -1;
        final pb = b.probability ?? -1;
        return pb.compareTo(pa);
      });
    return sorted.first;
  }

  static String labelForSpecializedApi(String apiId) {
    return switch (apiId) {
      'medical_prescription' => '处方笺识别',
      'medical_invoice' => '医疗发票识别',
      'medical_detail' => '医疗费用明细识别',
      'medical_statement' => '医疗费用结算单识别',
      'medical_report_detection' => '检验检查报告识别',
      'medical_summary' => '出院小结识别',
      'health_report' => '诊断报告识别',
      'medical_record' => '病案首页识别',
      'medical_outpatient' => '门诊病历识别',
      'medical_surgery' => '手术记录识别',
      'medical_summary_in_hospital' => '入院小结识别',
      _ => apiId,
    };
  }

  static String labelForRouteSource(String? code) {
    return switch (code) {
      'keyword_text' => '路由依据：识别全文关键词（标题若被换行拆开亦可匹配）',
      'doc_classify' => '路由依据：百度云文档分类',
      _ => '',
    };
  }

  /// 解析后端 [MedicalOcrView] JSON（不含 ApiResponse 外层）。
  factory MedicalOcrResult.fromApiData(Map<String, dynamic> data) {
    final fullText = data['fullText'] as String? ?? '';
    final rawAny = data['raw'];
    Map<String, dynamic>? rawMap;
    if (rawAny is Map<String, dynamic>) {
      rawMap = rawAny;
    } else if (rawAny is Map) {
      rawMap = Map<String, dynamic>.from(rawAny);
    }

    List<DocumentClassItem>? classes;
    final dc = data['documentClasses'];
    if (dc is List) {
      classes = dc.map(DocumentClassItem.tryParse).whereType<DocumentClassItem>().toList();
      if (classes.isEmpty) classes = null;
    }

    Map<String, dynamic>? classifyRawMap;
    final cr = data['classifyRaw'];
    if (cr is Map<String, dynamic>) {
      classifyRawMap = cr;
    } else if (cr is Map) {
      classifyRawMap = Map<String, dynamic>.from(cr);
    }

    final routedId = data['routedSpecializedApi'] as String?;

    Map<String, dynamic>? specRaw;
    final sr = data['specializedRaw'];
    if (sr is Map<String, dynamic>) {
      specRaw = sr;
    } else if (sr is Map) {
      specRaw = Map<String, dynamic>.from(sr);
    }

    final warn = data['classificationWarning'] as String?;
    final routeSrc = data['structuredRouteSource'] as String?;

    return MedicalOcrResult(
      fullText: fullText,
      raw: rawMap,
      documentClasses: classes,
      classifyRaw: classifyRawMap,
      routedSpecializedApi: routedId,
      specializedRaw: specRaw,
      classificationWarning: warn != null && warn.isEmpty ? null : warn,
      structuredRouteSource:
          routeSrc != null && routeSrc.isEmpty ? null : routeSrc,
    );
  }
}

final class MedicalOcrApi {
  MedicalOcrApi._();

  static Future<MedicalOcrResult> recognizeMedicalDocument(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
    });
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/ocr/medical-document',
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return MedicalOcrResult.fromApiData(api.data!);
  }
}
