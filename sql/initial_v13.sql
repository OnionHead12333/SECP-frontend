-- ======================================================
-- 数据库初始数据（V13）
-- 对齐 table_v13.sql；在 V11 种子数据基础上增加兴趣社群演示数据
-- 不包含 ai_medical_qa_knowledge 全量数据（请用 CSV 等方式单独导入）
-- 所有用户密码均为 'password'（BCrypt 占位哈希，生产请替换）
-- 新建库：在 table_v13.sql 之后执行本脚本
-- ======================================================

USE elder;
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE direct_messages;
TRUNCATE TABLE direct_message_threads;
TRUNCATE TABLE elder_friends;
TRUNCATE TABLE interest_community_messages;
TRUNCATE TABLE community_peer_seed_log;
TRUNCATE TABLE interest_community_memberships;
TRUNCATE TABLE community_demo_peer_profiles;
TRUNCATE TABLE interest_communities;
TRUNCATE TABLE ai_consultation_message;
TRUNCATE TABLE ai_family_notification;
TRUNCATE TABLE ai_feedback;
TRUNCATE TABLE ai_manual_handoff;
TRUNCATE TABLE ai_preconsultation_record;
TRUNCATE TABLE ai_consultation;
TRUNCATE TABLE ai_knowledge_import_job;
TRUNCATE TABLE ai_training_job;
TRUNCATE TABLE ai_medical_risk_rule;
TRUNCATE TABLE ai_medical_qa_knowledge;
TRUNCATE TABLE ai_chat_logs;
TRUNCATE TABLE reminder_execution_logs;
TRUNCATE TABLE medical_reminders;
TRUNCATE TABLE exercise_reminders;
TRUNCATE TABLE water_reminders;
TRUNCATE TABLE medicine_reminders;
TRUNCATE TABLE medical_calendar_events;
TRUNCATE TABLE medical_documents;
TRUNCATE TABLE medical_archive_folders;
TRUNCATE TABLE medical_events;
TRUNCATE TABLE medical_records;
TRUNCATE TABLE health_metrics;
TRUNCATE TABLE emergency_alerts;
TRUNCATE TABLE elder_guard_rules;
TRUNCATE TABLE location_logs;
TRUNCATE TABLE activity_logs;
TRUNCATE TABLE geofences;
TRUNCATE TABLE emergency_contacts;
TRUNCATE TABLE family_bindings;
TRUNCATE TABLE elder_location_guard_settings;
TRUNCATE TABLE elder_profiles;
TRUNCATE TABLE notification_settings;
TRUNCATE TABLE users;

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO users (id, username, password_hash, role, name, phone, avatar_url, gender, birthday, created_at, updated_at) VALUES
(1, '13800138001', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'elder', '张建国', '13800138001', '/avatars/elder1.jpg', 'male', '1950-05-15', NOW(), NOW()),
(2, '13800138002', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'elder', '李秀英', '13800138002', '/avatars/elder2.jpg', 'female', '1955-08-22', NOW(), NOW()),
(3, '13800138003', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'elder', '王德明', '13800138003', '/avatars/elder3.jpg', 'male', '1948-11-30', NOW(), NOW()),
(4, '13900139001', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'child', '张明', '13900139001', '/avatars/child1.jpg', 'male', '1980-03-10', NOW(), NOW()),
(5, '13900139002', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'child', '李华', '13900139002', '/avatars/child2.jpg', 'female', '1982-07-18', NOW(), NOW()),
(6, '13900139003', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'child', '王芳', '13900139003', '/avatars/child3.jpg', 'female', '1978-12-05', NOW(), NOW()),
(7, '13900139004', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'child', '张伟', '13900139004', NULL, 'male', '1985-06-20', NOW(), NOW()),
(8, '13900139005', '$2a$10$NkMwrJ5K6VwZQyX9qVZ8xO3rZq5vYhTqHpLmNcBvCxZaSdFgHjK', 'child', '陈敏', '13900139005', '/avatars/child4.jpg', 'female', '1988-09-01', NOW(), NOW());

INSERT INTO elder_profiles (
  id, name, phone, gender, birthday, claimed_user_id, status, created_by_child_id,
  location_permission_foreground, location_permission_background, permission_updated_at,
  created_at, updated_at
) VALUES
(1, '张建国', '13800138001', 'male', '1950-05-15', 1, 'claimed', 4, 1, 1, '2026-04-11 09:55:00', NOW(), NOW()),
(2, '李秀英', '13800138002', 'female', '1955-08-22', 2, 'claimed', 5, 1, 0, '2026-04-11 09:40:00', NOW(), NOW()),
(3, '王德明', '13800138003', 'male', '1948-11-30', 3, 'claimed', 6, 1, 0, '2026-04-11 08:20:00', NOW(), NOW()),
(4, '赵美兰', '13800138111', 'female', '1957-04-18', NULL, 'unclaimed', 8, 0, 0, NULL, NOW(), NOW()),
(5, '周桂芳', '13800138112', 'female', '1960-01-09', NULL, 'unclaimed', 4, 0, 0, NULL, NOW(), NOW());

INSERT INTO family_bindings (id, elder_profile_id, child_user_id, relation, is_primary, status, created_at, updated_at) VALUES
(1, 1, 4, '儿子', 1, 'active', NOW(), NOW()),
(2, 1, 7, '儿子', 0, 'active', NOW(), NOW()),
(3, 2, 5, '女儿', 1, 'active', NOW(), NOW()),
(4, 2, 8, '女儿', 0, 'pending', NOW(), NOW()),
(5, 3, 6, '女儿', 1, 'active', NOW(), NOW()),
(6, 4, 8, '女儿', 1, 'pending', NOW(), NOW()),
(7, 5, 4, '儿媳', 1, 'pending', NOW(), NOW());

INSERT INTO emergency_contacts (id, elder_profile_id, name, phone, relation, priority, created_at, updated_at) VALUES
(1, 1, '张明', '13900139001', '儿子', 1, NOW(), NOW()),
(2, 1, '张伟', '13900139004', '儿子', 2, NOW(), NOW()),
(3, 1, '王淑芬', '13700137001', '配偶', 3, NOW(), NOW()),
(4, 2, '李华', '13900139002', '女儿', 1, NOW(), NOW()),
(5, 2, '李国强', '13600136001', '配偶', 2, NOW(), NOW()),
(6, 3, '王芳', '13900139003', '女儿', 1, NOW(), NOW());

INSERT INTO medical_records (id, elder_profile_id, record_type, image_url, ocr_text, diagnosis, visit_time, review_time, remark, created_at, updated_at) VALUES
(1, 1, 'prescription', '/images/prescription1.jpg', '阿司匹林肠溶片 100mg 每日一次', '高血压、冠心病', '2024-01-15 09:30:00', '2024-04-15 00:00:00', '定期复查血压', NOW(), NOW()),
(2, 1, 'examination', '/images/exam1.jpg', '血压: 145/95mmHg 心率: 78次/分', '高血压2级', '2024-01-15 10:00:00', NULL, '建议低盐饮食', NOW(), NOW()),
(3, 1, 'review', '/images/followup1.jpg', '血压控制良好', '高血压', '2024-02-20 14:00:00', '2024-05-20 00:00:00', '继续服药', NOW(), NOW()),
(4, 2, 'case', '/images/record1.jpg', '2型糖尿病史5年', '2型糖尿病', '2023-12-10 08:30:00', '2024-03-10 00:00:00', '注意监测血糖', NOW(), NOW()),
(5, 2, 'examination', '/images/exam2.jpg', '空腹血糖: 7.2mmol/L 糖化血红蛋白: 7.5%', '糖尿病', '2024-01-20 09:00:00', NULL, '血糖控制尚可', NOW(), NOW()),
(6, 3, 'prescription', '/images/prescription2.jpg', '硝苯地平缓释片 30mg 每日一次', '高血压', '2024-01-10 11:00:00', '2024-04-10 00:00:00', NULL, NOW(), NOW()),
(7, 3, 'examination', '/images/exam3.jpg', '骨密度 T值 -2.5', '骨质疏松', '2024-02-01 10:30:00', '2024-08-01 00:00:00', '建议补充钙剂', NOW(), NOW());

INSERT INTO medical_events (id, elder_profile_id, record_id, title, event_type, event_time, repeat_rule, status, created_by, created_at, updated_at) VALUES
(1, 1, 1, '服用降压药', 'medicine', '2024-04-06 08:00:00', 'daily', 'pending', 'ocr', NOW(), NOW()),
(2, 1, NULL, '医院复诊', 'review', '2024-04-15 09:00:00', 'none', 'pending', 'child', NOW(), NOW()),
(3, 1, NULL, '测量血压', 'examination', '2024-04-07 19:00:00', 'weekly', 'pending', 'elder', NOW(), NOW()),
(4, 2, 4, '测量血糖', 'examination', '2024-04-06 07:30:00', 'daily', 'pending', 'elder', NOW(), NOW()),
(5, 2, NULL, '内分泌科复诊', 'review', '2024-04-10 14:00:00', 'none', 'pending', 'child', NOW(), NOW()),
(6, 3, 6, '服用降压药', 'medicine', '2024-04-06 08:30:00', 'daily', 'pending', 'ocr', NOW(), NOW()),
(7, 3, NULL, '骨密度复查', 'examination', '2024-08-01 09:00:00', 'none', 'pending', 'child', NOW(), NOW());

-- 提醒数据（四表拆分）
INSERT INTO medicine_reminders (
  id, elder_profile_id, title, medicine_name, dosage, frequency_rule,
  source_type, related_event_id, remind_time, repeat_rule, enabled, status, created_by, created_at, updated_at
) VALUES
(1, 1, '服用降压药', '降压药', '1片', 'daily', 'ocr', 1, '2024-04-06 08:00:00', 'daily', 1, 'pending', 'elder', NOW(), NOW()),
(2, 3, '服用降压药', '硝苯地平缓释片', '30mg', 'daily', 'ocr', 6, '2024-04-06 08:30:00', 'daily', 1, 'pending', 'elder', NOW(), NOW());

INSERT INTO medical_reminders (
  id, elder_profile_id, title, medical_type, related_event_id,
  source_type, remind_time, repeat_rule, enabled, status, created_by, created_at, updated_at
) VALUES
(1, 1, '测量血压', 'examination', 3, 'child_remote', '2024-04-07 19:00:00', 'weekly', 1, 'pending', 'child', NOW(), NOW()),
(2, 1, '复诊提醒', 'review', 2, 'child_remote', '2024-04-15 08:30:00', 'none', 1, 'pending', 'child', NOW(), NOW()),
(3, 2, '测量血糖', 'examination', 4, 'elder_manual', '2024-04-06 07:30:00', 'daily', 1, 'pending', 'elder', NOW(), NOW()),
(4, 2, '内分泌复诊', 'review', 5, 'child_remote', '2024-04-10 13:30:00', 'none', 1, 'pending', 'child', NOW(), NOW()),
(5, 3, '骨密度复查', 'examination', 7, 'child_remote', '2024-08-01 08:30:00', 'none', 1, 'pending', 'child', NOW(), NOW());

INSERT INTO water_reminders (
  id, elder_profile_id, title,
  daily_target_ml, per_intake_ml, interval_minutes, start_time, end_time,
  today_intake_ml, last_intake_time,
  source_type, remind_time, repeat_rule, enabled, status, created_by, created_at, updated_at
) VALUES
(1, 1, '喝水提醒', 1600, 200, 120, '08:00:00', '20:00:00', 400, '2026-04-11 09:30:00', 'elder_manual', '2026-04-11 10:30:00', 'daily', 1, 'pending', 'elder', NOW(), NOW()),
(2, 2, '喝水提醒', 1500, 200, 120, '08:00:00', '20:00:00', 200, '2026-04-11 09:00:00', 'child_remote', '2026-04-11 10:30:00', 'daily', 1, 'pending', 'child', NOW(), NOW());

INSERT INTO exercise_reminders (
  id, elder_profile_id, title,
  exercise_type, goal_value, goal_unit,
  interval_minutes, start_time, end_time,
  source_type, remind_time, repeat_rule, enabled, status, created_by, created_at, updated_at
) VALUES
(1, 1, '散步锻炼', 'walk', 30, 'minutes', 240, '08:00:00', '18:00:00', 'child_remote', '2026-04-11 18:00:00', 'daily', 1, 'self_confirmed', 'child', NOW(), NOW()),
(2, 3, '太极锻炼', 'taichi', 1, 'times', 240, '08:00:00', '18:00:00', 'elder_manual', '2026-04-12 08:00:00', 'weekly', 1, 'pending', 'elder', NOW(), NOW());

INSERT INTO reminder_execution_logs (
  id, elder_profile_id, reminder_kind, reminder_id,
  scheduled_at, confirmed_at, confirm_source, is_timeout, status, created_at
) VALUES
(1, 1, 'water', 1, '2026-04-11 10:30:00', '2026-04-11 10:33:00', 'manual', 0, 'confirmed', NOW()),
(2, 1, 'exercise', 1, '2026-04-11 18:00:00', '2026-04-11 18:20:00', 'manual', 0, 'confirmed', NOW()),
(3, 2, 'water', 2, '2026-04-11 10:30:00', NULL, 'system', 1, 'timeout', NOW());

INSERT INTO health_metrics (id, elder_profile_id, metric_type, value, unit, source, recorded_at, remark, created_at) VALUES
(1, 1, 'blood_pressure', '135/85', 'mmHg', 'elder_input', '2024-04-01 08:00:00', '晨起空腹', NOW()),
(2, 1, 'blood_pressure', '142/90', 'mmHg', 'elder_input', '2024-04-02 08:00:00', '晨起空腹', NOW()),
(3, 1, 'heart_rate', '78', '次/分', 'device', '2024-04-01 08:00:00', NULL, NOW()),
(4, 1, 'weight', '72.5', 'kg', 'elder_input', '2024-04-01 07:00:00', NULL, NOW()),
(5, 2, 'blood_sugar', '7.2', 'mmol/L', 'device', '2024-04-01 07:30:00', '空腹', NOW()),
(6, 2, 'blood_sugar', '8.1', 'mmol/L', 'device', '2024-04-02 07:30:00', '空腹', NOW()),
(7, 2, 'blood_pressure', '128/82', 'mmHg', 'elder_input', '2024-04-01 15:00:00', '下午测量', NOW()),
(8, 3, 'blood_pressure', '145/92', 'mmHg', 'device', '2024-04-01 08:30:00', '服药前', NOW()),
(9, 3, 'heart_rate', '82', '次/分', 'device', '2024-04-01 08:30:00', NULL, NOW()),
(10, 3, 'weight', '65.0', 'kg', 'elder_input', '2024-04-01 07:00:00', NULL, NOW());

INSERT INTO location_logs (id, elder_profile_id, location_type, room_name, latitude, longitude, source, recorded_at) VALUES
(1, 1, 'indoor', NULL, 39.904200, 116.407400, 'gaode', '2026-04-11 08:00:00'),
(2, 1, 'outdoor', NULL, 39.905000, 116.408000, 'gaode', '2026-04-11 09:10:00'),
(3, 1, 'outdoor', NULL, 39.905050, 116.408030, 'gaode', '2026-04-11 09:45:00'),
(4, 2, 'indoor', NULL, 31.230400, 121.473700, 'gaode', '2026-04-11 07:20:00'),
(5, 2, 'outdoor', NULL, 31.235000, 121.478000, 'gaode', '2026-04-11 09:00:00'),
(6, 2, 'outdoor', NULL, 31.235010, 121.478010, 'gaode', '2026-04-11 09:50:00'),
(7, 3, 'indoor', NULL, 34.341600, 108.939800, 'gaode', '2026-04-11 08:30:00'),
(8, 3, 'outdoor', NULL, 34.345000, 108.940000, 'gaode', '2026-04-11 14:00:00');

INSERT INTO activity_logs (id, elder_profile_id, activity_type, start_time, end_time, duration, is_abnormal, created_at) VALUES
(1, 1, 'moving', '2026-04-11 09:00:00', '2026-04-11 09:30:00', 1800, 0, NOW()),
(2, 1, 'stationary', '2026-04-11 09:30:00', '2026-04-11 10:10:00', 2400, 0, NOW()),
(3, 2, 'go_out', '2026-04-11 08:40:00', '2026-04-11 09:00:00', 1200, 0, NOW()),
(4, 2, 'stationary', '2026-04-11 09:00:00', '2026-04-11 10:00:00', 3600, 1, NOW()),
(5, 3, 'stationary', '2026-04-11 08:30:00', '2026-04-11 10:30:00', 7200, 0, NOW());

INSERT INTO geofences (id, elder_profile_id, name, center_latitude, center_longitude, radius, is_enabled, created_at, updated_at) VALUES
(1, 1, '家', 39.904200, 116.407400, 500, 1, NOW(), NOW()),
(2, 1, '社区卫生站', 39.910000, 116.410000, 200, 1, NOW(), NOW()),
(3, 2, '家', 31.230400, 121.473700, 300, 1, NOW(), NOW()),
(4, 2, '女儿家', 31.240000, 121.480000, 500, 1, NOW(), NOW()),
(5, 3, '家', 34.341600, 108.939800, 400, 1, NOW(), NOW()),
(6, 3, '公园', 34.348000, 108.945000, 800, 0, NOW(), NOW());

INSERT INTO elder_guard_rules (id, elder_profile_id, enabled, active_start_time, active_end_time, home_inactivity_minutes, outside_inactivity_minutes, alert_min_interval_minutes, created_by_user_id, updated_by_user_id, created_at, updated_at) VALUES
(1, 1, 1, '08:00:00', '18:00:00', 120, 60, 120, 4, 4, NOW(), NOW()),
(2, 2, 1, '08:30:00', '19:00:00', 150, 60, 120, 5, 5, NOW(), NOW()),
(3, 3, 0, '08:00:00', '17:30:00', 120, 90, 180, 6, 6, NOW(), NOW());

INSERT INTO notification_settings (id, child_user_id, warning_push_enabled, sos_push_enabled, reminder_sync_enabled, updated_at) VALUES
(1, 4, 1, 1, 1, NOW()),
(2, 5, 1, 1, 1, NOW()),
(3, 6, 1, 1, 1, NOW()),
(4, 7, 1, 1, 0, NOW()),
(5, 8, 1, 1, 1, NOW());

INSERT INTO emergency_alerts (id, elder_profile_id, alert_type, trigger_mode, status, trigger_time, revoke_deadline, sent_time, cancel_time, cancel_mode, handled_time, handled_by, location_id, remark, created_at) VALUES
(1, 1, 'sos', 'button', 'handled', '2026-04-11 09:23:00', '2026-04-11 09:23:05', '2026-04-11 09:23:05', NULL, NULL, '2026-04-11 09:35:00', 4, 1, '老人一键求助，子女已处理', NOW()),
(2, 2, 'inactivity', 'rule_engine', 'sent', '2026-04-11 10:00:00', NULL, '2026-04-11 10:00:00', NULL, NULL, NULL, NULL, 6, '活跃时段内外出超过 60 分钟未检测到明显移动', NOW()),
(3, 3, 'abnormal_location', 'sensor', 'handled', '2026-04-11 10:30:00', NULL, '2026-04-11 10:30:00', NULL, NULL, '2026-04-11 10:45:00', 6, 8, '超出安全区域', NOW()),
(4, 1, 'sos', 'button', 'cancelled', '2026-04-11 08:00:00', '2026-04-11 08:00:05', NULL, '2026-04-11 08:00:03', 'button', NULL, NULL, 1, '老人点击后 3 秒内手动撤回', NOW()),
(5, 2, 'sos', 'button', 'pending_revoke', '2026-04-11 08:10:00', '2026-04-11 08:10:05', NULL, NULL, NULL, NULL, NULL, 5, '正在 5 秒撤回倒计时内', NOW());

INSERT INTO ai_chat_logs (id, user_id, elder_profile_id, role, message, created_at) VALUES
(1, 4, 1, 'user', '我父亲血压偏高，应该注意什么？', '2026-04-11 10:00:00'),
(2, 4, 1, 'assistant', '高血压患者应注意：1.低盐低脂饮食 2.规律服药 3.每天监测血压 4.适度运动 5.保持情绪稳定。', '2026-04-11 10:00:05'),
(3, 1, 1, 'user', '我的药快吃完了，什么时候去复诊？', '2026-04-11 14:30:00'),
(4, 1, 1, 'assistant', '根据记录，您需要在4月15日前复诊取药。', '2026-04-11 14:30:08'),
(5, 5, 2, 'user', '妈妈血糖今天有点高，怎么办？', '2026-04-11 08:00:00'),
(6, 5, 2, 'assistant', '空腹血糖8.1mmol/L略高，建议继续监测，如持续偏高请就医。', '2026-04-11 08:00:12');


-- ---------- AI 导诊等（来自 Navicat 导出，已排除 ai_medical_qa_knowledge 数据）----------
INSERT INTO `ai_consultation` VALUES (1, 1, 1, '头晕怎么办', 'text', '头晕怎么办 头晕怎么办 【简单说明】 基于检索到的相似问答，您的情况可能和相关症状有关。 【建议怎么做】 1. 先注意休息，观察症状变化。 2. 如果症状持续或加重，尽快就医。 3. 记录发作时间和伴随症状，方便后续判断。 【什么时候需要就医】 如果出现持续加重、胸闷、呼吸困难、发热不退或明显不适，请尽快就医。 【建议科室】 全科医学科 / 内科 / 导诊台 【安全提示】 本回答仅供健康咨询参考，不能替代医生诊断。 头晕两天了，没有发烧 头晕两天了，没有发烧', 'high', NULL, NULL, NULL, NULL, 1, 1, '【风险提醒】\n您描述的症状可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 请先保持安全姿势。\n2. 建议尽快联系家属或紧急联系人。\n3. 如果症状明显，请及时拨打急救电话或前往急诊。\n\n【建议科室】\n急诊科 / 相关专科。\n\n【家属提醒】\n建议同步给家属，方便家属及时了解情况。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'done', '2026-05-16 16:26:11', '2026-05-16 16:30:53', '急诊科', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (2, 1, 1, '我胸口闷，喘不上气', 'text', '我胸口闷，喘不上气', 'high', NULL, NULL, NULL, NULL, 1, 1, '【风险提醒】\n您描述的症状可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 请先保持安全姿势。\n2. 建议尽快联系家属或紧急联系人。\n3. 如果症状明显，请及时拨打急救电话或前往急诊。\n\n【建议科室】\n急诊科 / 相关专科。\n\n【家属提醒】\n建议同步给家属，方便家属及时了解情况。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'done', '2026-05-16 16:29:28', '2026-05-16 16:29:36', '急诊科', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (3, 1, 1, '我就是不舒服', 'text', '我就是不舒服', 'low', NULL, NULL, NULL, NULL, 0, 0, '【简单说明】\n基于检索到的相似问答，您的情况可能和相关症状有关。\n\n【建议怎么做】\n1. 先注意休息，观察症状变化。\n2. 如果症状持续或加重，尽快就医。\n3. 记录发作时间和伴随症状，方便后续判断。\n\n【什么时候需要就医】\n如果出现持续加重、胸闷、呼吸困难、发热不退或明显不适，请尽快就医。\n\n【建议科室】\n全科医学科 / 内科 / 导诊台\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'done', '2026-05-16 16:30:17', '2026-05-16 16:30:23', '全科医学科', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (5, 1, 1, '?????', 'text', '?????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 17:06:54', '2026-05-16 17:07:00', '全科医学科 / 内科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (6, 1, 1, '?????', 'text', '?????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:33:53', '2026-05-16 19:34:07', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (7, 1, 1, '??????', 'text', '??????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:34:32', '2026-05-16 19:34:46', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (8, 1, 1, '??????', 'text', '??????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:46:05', '2026-05-16 19:46:12', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (9, 1, 1, '?????', 'text', '?????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:48:34', '2026-05-16 19:48:41', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (10, 1, 1, '??', 'text', '??', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:49:00', '2026-05-16 19:49:07', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (11, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:50:03', '2026-05-16 19:50:11', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (12, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 19:57:27', '2026-05-16 19:57:36', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (13, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 20:20:51', '2026-05-16 20:20:59', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (14, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:04:47', '2026-05-16 21:04:55', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (15, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:55:26', '2026-05-16 21:55:34', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (16, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:56:21', '2026-05-16 21:56:29', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (17, 1, 1, '??????????????', 'text', '??????????????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:57:07', '2026-05-16 21:57:15', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (18, 1, 1, '?', 'text', '?', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:58:59', '2026-05-16 21:59:13', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (19, 1, 1, '?????', 'text', '?????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:59:14', '2026-05-16 21:59:28', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (20, 1, 1, '??????', 'text', '??????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:59:28', '2026-05-16 21:59:43', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (21, 1, 1, '??????', 'text', '??????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:59:43', '2026-05-16 21:59:58', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (22, 1, 1, '????,????', 'text', '????,????', 'low', NULL, NULL, NULL, NULL, 0, 0, '【需要补充信息】\n您描述的信息还不够具体，我还不能准确判断应该往哪个方向建议。\n\n【请您补充】\n1. 具体哪里不舒服？\n2. 是疼、晕、闷、喘、发热，还是其他感觉？\n3. 持续多久了？\n4. 有没有胸痛、呼吸困难、说话不清、手脚无力、摔倒、出血等情况？\n\n【先做什么】\n如果现在症状明显加重，请先联系家属或及时就医。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'need_more_info', '2026-05-16 21:59:59', '2026-05-16 22:00:13', '全科医学科 / 导诊台', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation` VALUES (23, 1, 1, '我有点头晕，呼吸困难，手发抖', 'text', '我有点头晕，呼吸困难，手发抖', 'high', NULL, NULL, NULL, NULL, 1, 1, '【风险提醒】\n您描述的情况可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 先停止活动，保持安全姿势。\n2. 尽快联系家属或紧急联系人。\n3. 如果症状明显或持续加重，请及时前往急诊。\n\n【建议科室】\n急诊科 / 相关专科\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', NULL, 'done', '2026-05-16 22:01:05', '2026-05-16 22:01:19', '急诊科 / 相关专科', '本回答仅供健康咨询参考，不能替代医生诊断。');
INSERT INTO `ai_consultation_message` VALUES (1, 1, 'user', '头晕怎么办', 'text', '2026-05-16 16:26:11');
INSERT INTO `ai_consultation_message` VALUES (2, 1, 'assistant', '【简单说明】\n基于检索到的相似问答，您的情况可能和相关症状有关。\n\n【建议怎么做】\n1. 先注意休息，观察症状变化。\n2. 如果症状持续或加重，尽快就医。\n3. 记录发作时间和伴随症状，方便后续判断。\n\n【什么时候需要就医】\n如果出现持续加重、胸闷、呼吸困难、发热不退或明显不适，请尽快就医。\n\n【建议科室】\n全科医学科 / 内科 / 导诊台\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', 'normal_answer', '2026-05-16 16:26:17');
INSERT INTO `ai_consultation_message` VALUES (3, 2, 'user', '我胸口闷，喘不上气', 'text', '2026-05-16 16:29:28');
INSERT INTO `ai_consultation_message` VALUES (4, 2, 'assistant', '【风险提醒】\n您描述的症状可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 请先保持安全姿势。\n2. 建议尽快联系家属或紧急联系人。\n3. 如果症状明显，请及时拨打急救电话或前往急诊。\n\n【建议科室】\n急诊科 / 相关专科。\n\n【家属提醒】\n建议同步给家属，方便家属及时了解情况。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', 'high_risk_answer', '2026-05-16 16:29:36');
INSERT INTO `ai_consultation_message` VALUES (5, 3, 'user', '我就是不舒服', 'text', '2026-05-16 16:30:17');
INSERT INTO `ai_consultation_message` VALUES (6, 3, 'assistant', '【简单说明】\n基于检索到的相似问答，您的情况可能和相关症状有关。\n\n【建议怎么做】\n1. 先注意休息，观察症状变化。\n2. 如果症状持续或加重，尽快就医。\n3. 记录发作时间和伴随症状，方便后续判断。\n\n【什么时候需要就医】\n如果出现持续加重、胸闷、呼吸困难、发热不退或明显不适，请尽快就医。\n\n【建议科室】\n全科医学科 / 内科 / 导诊台\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', 'normal_answer', '2026-05-16 16:30:23');
INSERT INTO `ai_consultation_message` VALUES (7, 1, 'user', '头晕两天了，没有发烧', 'text', '2026-05-16 16:30:48');
INSERT INTO `ai_consultation_message` VALUES (8, 1, 'assistant', '【风险提醒】\n您描述的症状可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 请先保持安全姿势。\n2. 建议尽快联系家属或紧急联系人。\n3. 如果症状明显，请及时拨打急救电话或前往急诊。\n\n【建议科室】\n急诊科 / 相关专科。\n\n【家属提醒】\n建议同步给家属，方便家属及时了解情况。\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', 'high_risk_answer', '2026-05-16 16:30:53');
INSERT INTO `ai_consultation_message` VALUES (10, 5, 'user', '?????', 'text', '2026-05-16 17:06:54');
INSERT INTO `ai_consultation_message` VALUES (11, 6, 'user', '?????', 'text', '2026-05-16 19:33:53');
INSERT INTO `ai_consultation_message` VALUES (12, 7, 'user', '??????', 'text', '2026-05-16 19:34:32');
INSERT INTO `ai_consultation_message` VALUES (13, 8, 'user', '??????', 'text', '2026-05-16 19:46:05');
INSERT INTO `ai_consultation_message` VALUES (14, 9, 'user', '?????', 'text', '2026-05-16 19:48:34');
INSERT INTO `ai_consultation_message` VALUES (15, 10, 'user', '??', 'text', '2026-05-16 19:49:00');
INSERT INTO `ai_consultation_message` VALUES (16, 11, 'user', '?', 'text', '2026-05-16 19:50:03');
INSERT INTO `ai_consultation_message` VALUES (17, 12, 'user', '?', 'text', '2026-05-16 19:57:27');
INSERT INTO `ai_consultation_message` VALUES (18, 13, 'user', '?', 'text', '2026-05-16 20:20:51');
INSERT INTO `ai_consultation_message` VALUES (19, 14, 'user', '?', 'text', '2026-05-16 21:04:47');
INSERT INTO `ai_consultation_message` VALUES (20, 15, 'user', '?', 'text', '2026-05-16 21:55:26');
INSERT INTO `ai_consultation_message` VALUES (21, 16, 'user', '?', 'text', '2026-05-16 21:56:21');
INSERT INTO `ai_consultation_message` VALUES (22, 17, 'user', '??????????????', 'text', '2026-05-16 21:57:07');
INSERT INTO `ai_consultation_message` VALUES (23, 18, 'user', '?', 'text', '2026-05-16 21:58:59');
INSERT INTO `ai_consultation_message` VALUES (24, 19, 'user', '?????', 'text', '2026-05-16 21:59:14');
INSERT INTO `ai_consultation_message` VALUES (25, 20, 'user', '??????', 'text', '2026-05-16 21:59:28');
INSERT INTO `ai_consultation_message` VALUES (26, 21, 'user', '??????', 'text', '2026-05-16 21:59:43');
INSERT INTO `ai_consultation_message` VALUES (27, 22, 'user', '????,????', 'text', '2026-05-16 21:59:59');
INSERT INTO `ai_consultation_message` VALUES (28, 23, 'user', '我有点头晕，呼吸困难，手发抖', 'text', '2026-05-16 22:01:05');
INSERT INTO `ai_consultation_message` VALUES (29, 23, 'assistant', '【风险提醒】\n您描述的情况可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 先停止活动，保持安全姿势。\n2. 尽快联系家属或紧急联系人。\n3. 如果症状明显或持续加重，请及时前往急诊。\n\n【建议科室】\n急诊科 / 相关专科\n\n【安全提示】\n本回答仅供健康咨询参考，不能替代医生诊断。', 'high_risk_answer', '2026-05-16 22:01:19');
INSERT INTO `ai_family_notification` VALUES (1, 1, 1, 1, 'consultation', '老人问题：头晕怎么办\n风险等级：high\nAI 回答摘要：【风险提醒】\n您描述的症状可能存在较高风险，建议尽快就医。\n\n【建议立即做】\n1. 请先保持安全姿势。\n2. 建议尽快联系家属或紧急联系人。\n3. 如果症状明显...\n推荐科室：急诊科\n是否建议就医：true\n咨询时间：2026-05-16T16:26:11', 'sent', 'unread', '2026-05-16 16:38:28', NULL, '2026-05-16 16:38:27');
INSERT INTO `ai_feedback` VALUES (1, 1, 1, 'helpful', '回答清楚', 1, 0, '2026-05-16 16:39:02', '2026-05-16 16:39:01');
INSERT INTO `ai_knowledge_import_job` VALUES (1, 'medical_qa_dataset.csv', 'D:\\Desktop\\SECP\\SCEP-backend\\backend\\data\\medical_qa_dataset.csv', 'success', 34809, 25889, 8735, NULL, '2026-05-15 19:57:48', '2026-05-15 22:17:44');
INSERT INTO `ai_training_job` VALUES (1, 'tfidf', 'success', 25889, 25889, 0, 'data\\ai-index\\ai_medical_qa_index.txt', '2026-05-16 13:24:42', '2026-05-16 13:24:45', 2937, NULL, '2026-05-16 13:24:42', '2026-05-16 13:24:45');

-- 老人定位守护设置：与 elder_profiles 及 location_logs 对齐（无轨迹档案 last_upload 为空）
INSERT INTO elder_location_guard_settings (
  elder_profile_id, enabled, mode, interval_seconds, outside_interval_seconds,
  background_required, foreground_granted, background_granted, battery_optimization_ignored,
  last_started_at, last_stopped_at, last_upload_at, last_error,
  updated_by, updated_at, created_at
)
SELECT
  ep.id,
  0,
  'off',
  600,
  300,
  1,
  COALESCE(ep.location_permission_foreground, 0),
  COALESCE(ep.location_permission_background, 0),
  0,
  NULL,
  NULL,
  latest.last_upload_at,
  NULL,
  ep.claimed_user_id,
  NOW(),
  NOW()
FROM elder_profiles ep
LEFT JOIN (
  SELECT elder_profile_id, MAX(recorded_at) AS last_upload_at
  FROM location_logs
  GROUP BY elder_profile_id
) latest ON latest.elder_profile_id = ep.id;


-- ---------- 兴趣社群（对齐前端 CommunityCatalog / 群聊 / 好友 / 私聊）----------
INSERT INTO interest_communities (id, name, short_description, preview_icon, member_hint, sort_order, is_active, created_at, updated_at) VALUES
('taiji', '太极晨练群', '一起练站桩、步法与呼吸节律，互相提醒出门时间。', '🥋', '约 328 人在练', 1, 1, NOW(), NOW()),
('calligraphy', '书法兴趣班', '晒作品、聊聊笔墨纸砚，零基础也能练字。', '🖌️', '约 241 人在写', 2, 1, NOW(), NOW()),
('fitness', '健身活力群', '散步、徒手操、量力而行的小力量训练。', '💪', '约 417 人在动', 3, 1, NOW(), NOW()),
('travel', '慢旅游分享', '交流周边游、跟团游经验，互帮提醒行程与安全。', '🧭', '约 289 人在聊', 4, 1, NOW(), NOW());

INSERT INTO community_demo_peer_profiles (scope_key, display_name, phone, hint, emoji, linked_elder_profile_id, created_at) VALUES
('demo_peer_wang', '王阿姨', '13800001101', '太极晨练群 · 常约公园晨练', '👵', NULL, NOW()),
('demo_peer_li', '李叔叔', '13800001102', '太极晨练群 · 爱聊养生', '👴', NULL, NOW()),
('demo_peer_zhang', '张大姐', '13800001103', '书法兴趣班 · 擅长楷书', '👩', NULL, NOW()),
('demo_peer_zhao', '赵师傅', '13800001104', '健身活力群 · 每天散步', '🧔', NULL, NOW()),
('demo_peer_sun', '孙奶奶', '13800001105', '慢旅游分享 · 周边游达人', '👵', NULL, NOW());

INSERT INTO interest_community_memberships (id, elder_profile_id, community_id, scope_key, status, joined_at, left_at, updated_at) VALUES
(1, 1, 'taiji', 'phone_13800138001', 'active', '2026-04-01 08:00:00', NULL, NOW()),
(2, 1, 'calligraphy', 'phone_13800138001', 'active', '2026-04-02 09:30:00', NULL, NOW()),
(3, 2, 'calligraphy', 'phone_13800138002', 'active', '2026-04-03 10:00:00', NULL, NOW()),
(4, 2, 'travel', 'phone_13800138002', 'active', '2026-04-05 14:20:00', NULL, NOW()),
(5, 3, 'taiji', 'phone_13800138003', 'active', '2026-04-01 07:40:00', NULL, NOW()),
(6, 3, 'fitness', 'phone_13800138003', 'active', '2026-04-06 16:10:00', NULL, NOW());

INSERT INTO interest_community_messages (
  id, community_id, sender_scope_key, sender_elder_profile_id, sender_display_name, sender_role,
  message_kind, text_content, audio_url, duration_ms, created_at
) VALUES
('welcome_taiji', 'taiji', 'system', NULL, '群助手', 'elder', 'text', '欢迎来到太极晨练群！按住底部绿色按钮即可发送语音消息。', NULL, 0, '2026-04-01 08:05:00.000'),
('welcome_calligraphy', 'calligraphy', 'system', NULL, '群助手', 'elder', 'text', '欢迎来到书法兴趣班！按住底部绿色按钮即可发送语音消息。', NULL, 0, '2026-04-02 09:35:00.000'),
('welcome_fitness', 'fitness', 'system', NULL, '群助手', 'elder', 'text', '欢迎来到健身活力群！按住底部绿色按钮即可发送语音消息。', NULL, 0, '2026-04-06 16:15:00.000'),
('welcome_travel', 'travel', 'system', NULL, '群助手', 'elder', 'text', '欢迎来到慢旅游分享！按住底部绿色按钮即可发送语音消息。', NULL, 0, '2026-04-05 14:25:00.000'),
('demo_peer_taiji_1', 'taiji', 'demo_peer_wang', NULL, '王阿姨', 'elder', 'text', '大家明天照常去公园练太极，记得带水杯。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:20:00')),
('demo_peer_taiji_2', 'taiji', 'demo_peer_li', NULL, '李叔叔', 'elder', 'text', '收到，我上午也过去，咱们老地方见。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:35:00')),
('demo_peer_calligraphy_1', 'calligraphy', 'demo_peer_wang', NULL, '王阿姨', 'elder', 'text', '大家明天照常去公园练太极，记得带水杯。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:20:00')),
('demo_peer_calligraphy_2', 'calligraphy', 'demo_peer_li', NULL, '李叔叔', 'elder', 'text', '收到，我上午也过去，咱们老地方见。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:35:00')),
('demo_peer_fitness_1', 'fitness', 'demo_peer_wang', NULL, '王阿姨', 'elder', 'text', '大家明天照常去公园练太极，记得带水杯。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:20:00')),
('demo_peer_fitness_2', 'fitness', 'demo_peer_li', NULL, '李叔叔', 'elder', 'text', '收到，我上午也过去，咱们老地方见。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:35:00')),
('demo_peer_travel_1', 'travel', 'demo_peer_wang', NULL, '王阿姨', 'elder', 'text', '大家明天照常去公园练太极，记得带水杯。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:20:00')),
('demo_peer_travel_2', 'travel', 'demo_peer_li', NULL, '李叔叔', 'elder', 'text', '收到，我上午也过去，咱们老地方见。', NULL, 0, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:35:00')),
('voice_taiji_elder1_1', 'taiji', 'phone_13800138001', 1, '张建国', 'elder', 'voice', NULL, '/uploads/community_voice/taiji_elder1_20260410.m4a', 4200, '2026-04-10 07:50:00.000'),
('voice_calligraphy_elder2_1', 'calligraphy', 'phone_13800138002', 2, '李秀英', 'elder', 'voice', NULL, '/uploads/community_voice/calligraphy_elder2_20260409.m4a', 5600, '2026-04-09 15:20:00.000');

INSERT INTO community_peer_seed_log (community_id, seeded_at) VALUES
('taiji', NOW()),
('calligraphy', NOW()),
('fitness', NOW()),
('travel', NOW());

INSERT INTO elder_friends (id, owner_elder_profile_id, owner_scope_key, friend_scope_key, friend_elder_profile_id, display_name, phone, hint, emoji, added_at) VALUES
(1, 1, 'phone_13800138001', 'demo_peer_wang', NULL, '王阿姨', '13800001101', '太极晨练群 · 常约公园晨练', '👵', '2026-04-08 11:00:00'),
(2, 1, 'phone_13800138001', 'demo_peer_li', NULL, '李叔叔', '13800001102', '太极晨练群 · 爱聊养生', '👴', '2026-04-09 16:30:00'),
(3, 3, 'phone_13800138003', 'demo_peer_zhao', NULL, '赵师傅', '13800001104', '健身活力群 · 每天散步', '🧔', '2026-04-07 09:15:00');

INSERT INTO direct_message_threads (
  id, participant_a_scope_key, participant_b_scope_key,
  participant_a_elder_profile_id, participant_b_elder_profile_id,
  created_at, updated_at
) VALUES
(1, 'demo_peer_wang', 'phone_13800138001', NULL, 1, '2026-04-08 11:05:00', '2026-04-10 08:12:00');

INSERT INTO direct_messages (
  id, thread_id, sender_scope_key, sender_elder_profile_id, sender_display_name, sender_role,
  message_kind, text_content, audio_url, duration_ms, created_at
) VALUES
('direct_1_wang_voice', 1, 'demo_peer_wang', NULL, '王阿姨', 'elder', 'voice', NULL, '/uploads/community_voice/direct_wang_20260408.m4a', 3800, '2026-04-08 11:06:00.000'),
('direct_1_elder1_voice', 1, 'phone_13800138001', 1, '张建国', 'elder', 'voice', NULL, '/uploads/community_voice/direct_elder1_20260410.m4a', 5100, '2026-04-10 08:12:00.000');


SET FOREIGN_KEY_CHECKS = 1;
