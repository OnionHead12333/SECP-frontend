import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/auth/auth_session.dart';
import 'package:smart_elderly_care_mobile/features/auth/models/register_user_role.dart';
import 'package:smart_elderly_care_mobile/features/child/models/child_local_models.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_emergency_contact.dart';
import 'package:smart_elderly_care_mobile/features/elder/models/elder_help_request.dart';
import 'package:smart_elderly_care_mobile/features/interest_community/data/community_scope.dart';
import 'package:smart_elderly_care_mobile/features/interest_community/models/community_friend.dart';
import 'package:smart_elderly_care_mobile/features/interest_community/models/community_message.dart';
import 'package:smart_elderly_care_mobile/features/medical_hub/data/medical_hub_api.dart';
import 'package:smart_elderly_care_mobile/features/medical_hub/utils/medical_fulltext_structure.dart';
import 'package:smart_elderly_care_mobile/features/medical_ocr/data/medical_ocr_api.dart';

void main() {
  setUp(AuthSession.clear);
  tearDown(AuthSession.clear);

  group('TC-FE-21~26 Auth/session 与注册角色', () {
    test('TC-FE-21 RegisterUserRole 与后端 role 值一致', () {
      expect(RegisterUserRole.elder.apiValue, 'elder');
      expect(RegisterUserRole.child.apiValue, 'child');
      expect(RegisterUserRole.elder.label, '老人');
    });

    test('TC-FE-22 AuthSession token 为空时未登录', () {
      AuthSession.token = '';

      expect(AuthSession.isLoggedIn, isFalse);
    });

    test('TC-FE-23 AuthSession token 非空时为已登录', () {
      AuthSession.token = 'token-demo';

      expect(AuthSession.isLoggedIn, isTrue);
    });

    test('TC-FE-24 AuthSession 保存老人基础状态并通知变化', () {
      final before = AuthSession.sessionChanges.value;

      AuthSession.saveElderState(
        name: '李阿姨',
        phone: '138****7809',
        claimed: true,
        familyCount: 2,
        gender: 'female',
        birthday: '1950-01-01',
      );

      expect(AuthSession.elderName, '李阿姨');
      expect(AuthSession.elderClaimed, isTrue);
      expect(AuthSession.elderFamilyCount, 2);
      expect(AuthSession.sessionChanges.value, before + 1);
    });

    test('TC-FE-25 AuthSession clear 会清空老人状态', () {
      AuthSession.token = 'token-demo';
      AuthSession.elderId = 9;
      AuthSession.saveElderState(
        name: '李阿姨',
        phone: '138****7809',
        claimed: true,
        familyCount: 2,
      );

      AuthSession.clear();

      expect(AuthSession.token, isNull);
      expect(AuthSession.elderId, isNull);
      expect(AuthSession.elderName, isNull);
      expect(AuthSession.elderClaimed, isFalse);
      expect(AuthSession.elderFamilyCount, 0);
    });

    test('TC-FE-26 CommunityScope 优先使用老人手机号', () {
      AuthSession.elderPhone = '13800000000';
      AuthSession.elderId = 9;

      expect(CommunityScope.forCurrentElder(), 'phone_13800000000');
    });
  });

  group('TC-FE-27~38 医疗结构化展示逻辑', () {
    test('TC-FE-27 MedicalDisplayBlock 过滤无 type 项', () {
      final blocks = MedicalDisplayBlock.listFromJson([
        {'type': 'title', 'text': '检验报告'},
        {'text': '缺少类型'},
      ]);

      expect(blocks, hasLength(1));
      expect(blocks.first.type, 'title');
    });

    test('TC-FE-28 table block 能转成 MedicalResultTable', () {
      final block = MedicalDisplayBlock.listFromJson([
        {
          'type': 'table',
          'headers': ['项目', '结果'],
          'rows': [
            ['白细胞', '5.0'],
          ],
          'caption': '检验结果',
        },
      ]).first;

      expect(block.asTable, isNotNull);
      expect(block.asTable!.rows.first.first, '白细胞');
    });

    test('TC-FE-29 parseTableRowsField 会过滤误放表头行', () {
      final tables = parseTableRowsField([
        ['检验项目', '结果'],
        ['白细胞', '5.0', '10^9/L', '3.5-9.5'],
      ]);

      expect(tables, hasLength(1));
      expect(tables.first.rows, hasLength(1));
      expect(tables.first.headers, contains('检验项目'));
    });

    test('TC-FE-30 collectMedicalResultTables 优先使用 displayBlocks 表格', () {
      final tables = collectMedicalResultTables(
        displayBlocks: MedicalDisplayBlock.listFromJson([
          {
            'type': 'table',
            'headers': ['项目', '结果'],
            'rows': [
              ['血红蛋白', '130'],
            ],
          },
        ]),
        tableRowsRaw: [
          ['不会使用', '0'],
        ],
      );

      expect(tables, hasLength(1));
      expect(tables.first.rows.first.first, '血红蛋白');
    });

    test('TC-FE-31 百度双栏检验报告能拆成左右表', () {
      final tables = extractTablesFromBaiduMedicalReport({
        'Item': [
          [
            {
              'word_name': '项目名称',
              'word': 'WBC',
              'location': {'left': 100}
            },
            {'word_name': '结果', 'word': '5.0'},
          ],
          [
            {
              'word_name': '项目名称',
              'word': 'RBC',
              'location': {'left': 1500}
            },
            {'word_name': '结果', 'word': '4.5'},
          ],
        ],
      });

      expect(tables, hasLength(2));
      expect(tables.first.caption, contains('左栏'));
      expect(tables.last.caption, contains('右栏'));
    });

    test('TC-FE-32 resolveMedicalDocumentTitle 跳过页码标题', () {
      final title = resolveMedicalDocumentTitle(
        apiTitle: '第1页/共1页',
        specializedRaw: {
          'CommonData': [
            {'word_name': '检查项目', 'word': '血常规'},
          ],
        },
      );

      expect(title, '血常规');
    });

    test('TC-FE-33 structureMedicalFullText 能识别标题和键值对', () {
      final blocks = structureMedicalFullText('北京医院\n姓名：张三\n注意事项\n空腹检查');

      expect(blocks.first.kind, FullTextBlockKind.header);
      expect(blocks.any((b) => b.kind == FullTextBlockKind.keyValue), isTrue);
    });

    test('TC-FE-34 flattenSpecializedJson 会映射常见中文标签', () {
      final entries = flattenSpecializedJson({
        'patient_name': '张三',
        'sample_type': '血液',
      });

      expect(entries.map((e) => e.key), contains('姓名'));
      expect(entries.map((e) => e.key), contains('样本类型'));
    });

    test('TC-FE-35 structuredFieldsFromJson 会拼接列表值', () {
      final entries = structuredFieldsFromJson({
        '建议': ['复查', '空腹'],
      });

      expect(entries.single.value, '复查、空腹');
    });

    test('TC-FE-36 structuredErrorFromDetail 支持嵌套错误', () {
      final error = structuredErrorFromDetail({
        'ocr': {'structuredError': '结构化失败'},
      });

      expect(error, '结构化失败');
    });

    test('TC-FE-37 displayBlocksAreCodeOnlyKv 能识别项目代号列表', () {
      final blocks = MedicalDisplayBlock.listFromJson([
        {'type': 'kv', 'label': 'WBC', 'value': '5.0'},
        {'type': 'kv', 'label': 'RBC', 'value': '4.5'},
        {'type': 'kv', 'label': 'HGB', 'value': '130'},
        {'type': 'kv', 'label': 'PLT', 'value': '200'},
        {'type': 'kv', 'label': 'LYM%', 'value': '30'},
      ]);

      expect(displayBlocksAreCodeOnlyKv(blocks), isTrue);
    });

    test('TC-FE-38 kvEntriesFromDisplayBlocks 空值用占位符', () {
      final entries = kvEntriesFromDisplayBlocks(
        MedicalDisplayBlock.listFromJson([
          {'type': 'kv', 'label': '姓名', 'value': ''},
        ]),
      );

      expect(entries.single.value, '—');
    });
  });

  group('TC-FE-39~47 医疗 API 模型解析', () {
    test('TC-FE-39 DocumentClassItem 空类型回退未知', () {
      final item = DocumentClassItem.tryParse({'type': '', 'probability': 0.8});

      expect(item, isNotNull);
      expect(item!.type, '未知');
      expect(item.probability, 0.8);
    });

    test('TC-FE-40 MedicalOcrResult primaryClass 按置信度排序', () {
      final ocr = MedicalOcrResult.fromApiData({
        'fullText': '报告文本',
        'documentClasses': [
          {'type': '低置信度', 'probability': 0.1},
          {'type': '高置信度', 'probability': 0.9},
        ],
      });

      expect(ocr.primaryClass!.type, '高置信度');
    });

    test('TC-FE-41 MedicalOcrResult 能映射结构化 API 标签', () {
      expect(
        MedicalOcrResult.labelForSpecializedApi('medical_report_detection'),
        '检验检查报告识别',
      );
    });

    test('TC-FE-42 ExtractedMedicalFields 解析列表字段', () {
      final fields = ExtractedMedicalFields.tryParse({
        'docCategory': 'LAB',
        'detectedDateTexts': ['2026-06-06'],
        'normalizedDates': ['2026-06-06'],
        'matchedKeywords': ['检验'],
      });

      expect(fields, isNotNull);
      expect(fields!.matchedKeywords, contains('检验'));
    });

    test('TC-FE-43 SuggestedCalendarEvent 缺少 startAt 返回 null', () {
      expect(SuggestedCalendarEvent.tryParse({'title': '复查'}), isNull);
    });

    test('TC-FE-44 MedicalDocumentSummary 兼容 snake_case 字段', () {
      final summary = MedicalDocumentSummary.tryParse({
        'id': '12',
        'elder_profile_id': '9',
        'title': '血常规',
        'doc_category': 'LAB',
        'created_at': '2026-06-06T08:00:00Z',
      });

      expect(summary, isNotNull);
      expect(summary!.id, 12);
      expect(summary.elderProfileId, 9);
      expect(summary.docCategory, 'LAB');
    });

    test('TC-FE-45 MedicalArchiveFolder 空名称返回 null', () {
      expect(MedicalArchiveFolder.tryParse({'id': 1, 'name': ''}), isNull);
    });

    test('TC-FE-46 MedicalCalendarEventView 缺省 createdAt 使用 startAt', () {
      final event = MedicalCalendarEventView.tryParse({
        'id': 1,
        'elderProfileId': 9,
        'title': '复查',
        'startAt': '2026-06-06T08:00:00Z',
      });

      expect(event, isNotNull);
      expect(event!.createdAt, event.startAt);
    });

    test('TC-FE-47 MedicalSmartRecognitionResult 缺少 ocr 会抛错', () {
      expect(
        () => MedicalSmartRecognitionResult.parse({'documentId': 1}),
        throwsException,
      );
    });
  });

  group('TC-FE-48~58 社区、联系人与 SOS 模型', () {
    test('TC-FE-48 社群 brief 兼容 snake_case 字段', () {
      final brief = InterestCommunityBrief.fromJson({
        'id': 1,
        'name': '书法群',
        'short_description': '一起练字',
        'preview_icon': '✍',
        'member_hint': '12人',
        'joined': true,
      });

      expect(brief.id, '1');
      expect(brief.shortDescription, '一起练字');
      expect(brief.joined, isTrue);
    });

    test('TC-FE-49 语音消息时长小于一分钟按秒展示', () {
      expect(InterestCommunityVoiceMessage.formatDurationMs(2500), '3″');
    });

    test('TC-FE-50 语音消息时长超过一分钟按分秒展示', () {
      expect(InterestCommunityVoiceMessage.formatDurationMs(65000), '1:05');
    });

    test('TC-FE-51 消息可从 audioUrl 推断为 voice', () {
      final message = InterestCommunityVoiceMessage.fromJson({
        'id': 'm1',
        'communityId': 'c1',
        'role': 'elder',
        'senderDisplay': '张爷爷',
        'audioUrl': 'https://example.test/a.mp3',
        'duration': 2,
      });

      expect(message.isVoice, isTrue);
      expect(message.durationMs, 2000);
    });

    test('TC-FE-52 文本消息摘要显示正文', () {
      final message = InterestCommunityVoiceMessage.fromJson({
        'id': 'm1',
        'communityId': 'c1',
        'role': 'child',
        'senderDisplay': '家属',
        'kind': 'text',
        'textContent': '今天记得喝水',
      });

      expect(message.displaySummary, '今天记得喝水');
      expect(message.kindJson, 'text');
    });

    test('TC-FE-53 图片消息摘要显示图片占位', () {
      final message = InterestCommunityVoiceMessage.fromJson({
        'id': 'm2',
        'communityId': 'c1',
        'role': 'elder',
        'senderDisplay': '张爷爷',
        'image_url': 'https://example.test/p.png',
      });

      expect(message.isImage, isTrue);
      expect(message.displaySummary, '[图片]');
    });

    test('TC-FE-54 ElderFriendCandidate 兼容 friendScopeKey', () {
      final candidate = ElderFriendCandidate.fromJson({
        'friendScopeKey': 'phone_13800000000',
        'display_name': '王阿姨',
        'sender_emoji': '🙂',
      });

      expect(candidate.scopeKey, 'phone_13800000000');
      expect(candidate.displayName, '王阿姨');
      expect(candidate.emoji, '🙂');
    });

    test('TC-FE-55 ElderFriend addedAt ISO 字符串可解析', () {
      final friend = ElderFriend.fromJson({
        'scope_key': 'phone_13800000000',
        'display_name': '王阿姨',
        'phone': '13800000000',
        'added_at': '2026-06-06T08:00:00Z',
      });

      expect(friend.addedAtMillis, greaterThan(0));
      expect(friend.toCandidate().scopeKey, friend.scopeKey);
    });

    test('TC-FE-56 ElderEmergencyContact priority=1 视为主联系人', () {
      final contact = ElderEmergencyContact.fromJson({
        'contactId': 7,
        'name': '家属',
        'phone': '13800000000',
        'priority': 1,
        'remark': '默认联系',
      });

      expect(contact.id, '7');
      expect(contact.isPrimary, isTrue);
      expect(contact.note, '默认联系');
    });

    test('TC-FE-57 ElderHelpRequest 支持 snake_case 时间字段', () {
      final request = ElderHelpRequest.fromJson({
        'id': 3,
        'status': 'sent',
        'trigger_time': '2026-06-06T08:00:00Z',
        'sent_time': '2026-06-06T08:01:00Z',
      });

      expect(request.alertId, 3);
      expect(request.isSent, isTrue);
      expect(request.sentTime, isNotNull);
    });

    test('TC-FE-58 CommunityScope 能从绑定老人提示中提取手机号', () {
      final scope = CommunityScope.forBoundElder(
        BoundElder(
          id: '9',
          displayName: '张爷爷',
          accountHint: '账号 13800000000',
        ),
      );

      expect(scope, 'phone_13800000000');
    });
  });
}
