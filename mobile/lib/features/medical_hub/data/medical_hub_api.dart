import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../medical_ocr/data/medical_ocr_api.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

int? _mapInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _mapStr(Map<String, dynamic> m, String camel, String snake) {
  final v = m[camel] ?? m[snake];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

final class ExtractedMedicalFields {
  ExtractedMedicalFields({
    required this.docCategory,
    required this.detectedDateTexts,
    required this.normalizedDates,
    required this.matchedKeywords,
  });

  final String? docCategory;
  final List<String> detectedDateTexts;
  final List<String> normalizedDates;
  final List<String> matchedKeywords;

  static ExtractedMedicalFields? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final dc = m['docCategory'] as String?;
    List<String> listStr(String key) {
      final v = m[key];
      if (v is! List) return [];
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }

    return ExtractedMedicalFields(
      docCategory: dc,
      detectedDateTexts: listStr('detectedDateTexts'),
      normalizedDates: listStr('normalizedDates'),
      matchedKeywords: listStr('matchedKeywords'),
    );
  }
}

final class SuggestedCalendarEvent {
  SuggestedCalendarEvent({
    required this.eventType,
    required this.title,
    required this.startAt,
    this.notes,
  });

  final String eventType;
  final String title;
  final DateTime startAt;
  final String? notes;

  static SuggestedCalendarEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final st = m['startAt'] as String?;
    if (st == null) return null;
    final dt = DateTime.tryParse(st);
    if (dt == null) return null;
    return SuggestedCalendarEvent(
      eventType: m['eventType'] as String? ?? 'EXAM',
      title: m['title'] as String? ?? '医疗提醒',
      startAt: dt,
      notes: m['notes'] as String?,
    );
  }
}

final class MedicalSmartRecognitionResult {
  MedicalSmartRecognitionResult({
    required this.documentId,
    required this.title,
    required this.ocr,
    required this.extractedFields,
    required this.suggestedCalendarEvents,
    this.folderId,
    this.folderName,
  });

  final int documentId;
  final String? title;
  final MedicalOcrResult ocr;
  final ExtractedMedicalFields? extractedFields;
  final List<SuggestedCalendarEvent> suggestedCalendarEvents;
  final int? folderId;
  final String? folderName;

  static MedicalSmartRecognitionResult parse(Map<String, dynamic> data) {
    final ocrRaw = data['ocr'];
    if (ocrRaw is! Map) {
      throw Exception('缺少 ocr 字段');
    }
    final ext = ExtractedMedicalFields.tryParse(data['extractedFields']);
    final sugList = data['suggestedCalendarEvents'];
    final sugs = <SuggestedCalendarEvent>[];
    if (sugList is List) {
      for (final e in sugList) {
        final s = SuggestedCalendarEvent.tryParse(e);
        if (s != null) sugs.add(s);
      }
    }
    return MedicalSmartRecognitionResult(
      documentId: (data['documentId'] as num?)?.toInt() ?? 0,
      title: _mapStr(Map<String, dynamic>.from(data), 'title', 'title'),
      ocr: MedicalOcrResult.fromApiData(Map<String, dynamic>.from(ocrRaw)),
      extractedFields: ext,
      suggestedCalendarEvents: sugs,
      folderId: _mapInt(data['folderId'] ?? data['folder_id']),
      folderName: _mapStr(Map<String, dynamic>.from(data), 'folderName', 'folder_name'),
    );
  }
}

final class MedicalDocumentSummary {
  MedicalDocumentSummary({
    required this.id,
    required this.elderProfileId,
    required this.title,
    required this.docCategory,
    required this.routedSpecializedApi,
    required this.createdAt,
    this.folderId,
    this.folderName,
  });

  final int id;
  final int elderProfileId;
  final String? title;
  final String? docCategory;
  final String? routedSpecializedApi;
  final DateTime createdAt;
  final int? folderId;
  final String? folderName;

  static MedicalDocumentSummary? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final ca = m['createdAt'] as String? ?? m['created_at'] as String?;
    if (ca == null) return null;
    final dt = DateTime.tryParse(ca);
    if (dt == null) return null;
    return MedicalDocumentSummary(
      id: _mapInt(m['id']) ?? 0,
      elderProfileId: _mapInt(m['elderProfileId'] ?? m['elder_profile_id']) ?? 0,
      title: _mapStr(m, 'title', 'title'),
      docCategory: _mapStr(m, 'docCategory', 'doc_category'),
      routedSpecializedApi: _mapStr(m, 'routedSpecializedApi', 'routed_specialized_api'),
      createdAt: dt,
      folderId: _mapInt(m['folderId'] ?? m['folder_id']),
      folderName: _mapStr(m, 'folderName', 'folder_name'),
    );
  }
}

final class MedicalArchiveFolder {
  MedicalArchiveFolder({
    required this.id,
    required this.elderProfileId,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final int elderProfileId;
  final String name;
  final int sortOrder;

  static MedicalArchiveFolder? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final name = _mapStr(m, 'name', 'name') ?? '';
    if (name.isEmpty) return null;
    return MedicalArchiveFolder(
      id: _mapInt(m['id']) ?? 0,
      elderProfileId: _mapInt(m['elderProfileId'] ?? m['elder_profile_id']) ?? 0,
      name: name,
      sortOrder: _mapInt(m['sortOrder'] ?? m['sort_order']) ?? 0,
    );
  }
}

final class MedicalCalendarEventView {
  MedicalCalendarEventView({
    required this.id,
    required this.elderProfileId,
    required this.eventType,
    required this.title,
    required this.startAt,
    this.endAt,
    this.notes,
    this.sourceDocumentId,
    required this.createdAt,
  });

  final int id;
  final int elderProfileId;
  final String eventType;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final String? notes;
  final int? sourceDocumentId;
  final DateTime createdAt;

  static MedicalCalendarEventView? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final sa = m['startAt'] as String?;
    if (sa == null) return null;
    final start = DateTime.tryParse(sa);
    if (start == null) return null;
    final ca = m['createdAt'] as String?;
    final created = ca != null ? DateTime.tryParse(ca) : null;
    return MedicalCalendarEventView(
      id: (m['id'] as num?)?.toInt() ?? 0,
      elderProfileId: (m['elderProfileId'] as num?)?.toInt() ?? 0,
      eventType: m['eventType'] as String? ?? 'EXAM',
      title: m['title'] as String? ?? '',
      startAt: start,
      endAt: (m['endAt'] as String?) != null ? DateTime.tryParse(m['endAt'] as String) : null,
      notes: m['notes'] as String?,
      sourceDocumentId: (m['sourceDocumentId'] as num?)?.toInt(),
      createdAt: created ?? start,
    );
  }
}

/// 医疗单据智能识别 / 归档 / 日历 API。
final class MedicalHubApi {
  MedicalHubApi._();

  static Future<MedicalSmartRecognitionResult> smartRecognize(
    File imageFile, {
    int? elderProfileId,
    int? folderId,
  }) async {
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
    };
    if (elderProfileId != null) {
      map['elderProfileId'] = elderProfileId;
    }
    if (folderId != null) {
      map['folderId'] = folderId;
    }
    final formData = FormData.fromMap(map);
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/medical/smart-recognize',
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
    return MedicalSmartRecognitionResult.parse(api.data!);
  }

  static Future<List<MedicalArchiveFolder>> listFolders({int? elderProfileId}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/medical/folders',
      queryParameters: {if (elderProfileId != null) 'elderProfileId': elderProfileId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
    final list = api.data;
    if (list is! List) return [];
    return list.map(MedicalArchiveFolder.tryParse).whereType<MedicalArchiveFolder>().toList();
  }

  static Future<MedicalArchiveFolder> createFolder({
    required int elderProfileId,
    required String name,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/medical/folders',
      data: {'elderProfileId': elderProfileId, 'name': name},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return MedicalArchiveFolder.tryParse(api.data!)!;
  }

  static Future<List<MedicalDocumentSummary>> listDocuments({
    int? elderProfileId,
    int? folderId,
    String? docCategory,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/medical/documents',
      queryParameters: {
        if (elderProfileId != null) 'elderProfileId': elderProfileId,
        if (folderId != null) 'folderId': folderId,
        if (docCategory != null && docCategory.isNotEmpty) 'docCategory': docCategory,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
    final list = api.data;
    if (list is! List) return [];
    return list.map(MedicalDocumentSummary.tryParse).whereType<MedicalDocumentSummary>().toList();
  }

  static Future<Map<String, dynamic>> documentDetail(int id, {int? elderProfileId}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/medical/documents/$id',
      queryParameters: {if (elderProfileId != null) 'elderProfileId': elderProfileId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  static Future<Uint8List> documentImageBytes(int id, {int? elderProfileId}) async {
    final res = await ApiClient.dio.get(
      '/v1/medical/documents/$id/file',
      queryParameters: {if (elderProfileId != null) 'elderProfileId': elderProfileId},
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('无法加载图片');
  }

  static Future<List<MedicalCalendarEventView>> listCalendarEvents({
    int? elderProfileId,
    required DateTime from,
    required DateTime to,
    String? eventType,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/medical/calendar/events',
      queryParameters: {
        if (elderProfileId != null) 'elderProfileId': elderProfileId,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
    final list = api.data;
    if (list is! List) return [];
    return list.map(MedicalCalendarEventView.tryParse).whereType<MedicalCalendarEventView>().toList();
  }

  static Future<MedicalCalendarEventView> createCalendarEvent({
    int? elderProfileId,
    required String eventType,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String? notes,
    int? sourceDocumentId,
  }) async {
    final payload = <String, dynamic>{
      'eventType': eventType,
      'title': title,
      'startAt': startAt.toIso8601String(),
      if (endAt != null) 'endAt': endAt.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (sourceDocumentId != null) 'sourceDocumentId': sourceDocumentId,
      if (elderProfileId != null) 'elderProfileId': elderProfileId,
    };
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/medical/calendar/events',
      data: payload,
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return MedicalCalendarEventView.tryParse(api.data!)!;
  }

  static Future<void> deleteCalendarEvent(int id, {int? elderProfileId}) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>(
      '/v1/medical/calendar/events/$id',
      queryParameters: {if (elderProfileId != null) 'elderProfileId': elderProfileId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (_) => null);
    if (!api.isSuccess) throw Exception(api.displayMessage);
  }

  /// 将单据移入文件夹；[folderId] 为 null 时表示移出文件夹（需 [assignFolderId] 为 true）。
  static Future<Map<String, dynamic>> moveDocumentToFolder(
    int id, {
    int? elderProfileId,
    int? folderId,
  }) {
    return patchDocument(
      id,
      elderProfileId: elderProfileId,
      folderId: folderId,
      assignFolderId: true,
    );
  }

  static Future<Map<String, dynamic>> patchDocument(
    int id, {
    int? elderProfileId,
    String? title,
    String? fullText,
    String? docCategory,
    int? folderId,
    bool assignFolderId = false,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (fullText != null) data['fullText'] = fullText;
    if (docCategory != null) data['docCategory'] = docCategory;
    if (assignFolderId) data['folderId'] = folderId;
    final res = await ApiClient.dio.patch<Map<String, dynamic>>(
      '/v1/medical/documents/$id',
      queryParameters: {if (elderProfileId != null) 'elderProfileId': elderProfileId},
      data: data,
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess) throw Exception(api.displayMessage);
    return api.data ?? <String, dynamic>{};
  }

  static Future<void> deleteDocument(int id, {int? elderProfileId}) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>(
      '/v1/medical/documents/$id',
      queryParameters: {if (elderProfileId != null) 'elderProfileId': elderProfileId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (_) => null);
    if (!api.isSuccess) throw Exception(api.displayMessage);
  }
}
