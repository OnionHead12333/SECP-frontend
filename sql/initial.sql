-- ======================================================
-- 数据库初始数据（融合版，对齐 sql/table.sql / 原 initial_v4）
-- 所有用户密码均为 'password'（BCrypt 占位哈希，生产请替换）
-- 新建库：在 table.sql 之后执行本脚本
-- ======================================================

USE elder;
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE ai_chat_logs;
TRUNCATE TABLE medical_reminders;
TRUNCATE TABLE exercise_reminders;
TRUNCATE TABLE water_reminders;
TRUNCATE TABLE medicine_reminders;
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

INSERT INTO elder_profiles (id, name, phone, gender, birthday, claimed_user_id, status, created_by_child_id, created_at, updated_at) VALUES
(1, '张建国', '13800138001', 'male', '1950-05-15', 1, 'claimed', 4, NOW(), NOW()),
(2, '李秀英', '13800138002', 'female', '1955-08-22', 2, 'claimed', 5, NOW(), NOW()),
(3, '王德明', '13800138003', 'male', '1948-11-30', 3, 'claimed', 6, NOW(), NOW()),
(4, '赵美兰', '13800138111', 'female', '1957-04-18', NULL, 'unclaimed', 8, NOW(), NOW()),
(5, '周桂芳', '13800138112', 'female', '1960-01-09', NULL, 'unclaimed', 4, NOW(), NOW());

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

-- 提醒数据（按 4 张提醒表写入）
INSERT INTO medicine_reminders (
  id, elder_profile_id, title, medicine_name, dosage, frequency_rule,
  source_type, related_event_id, remind_time, repeat_rule, status, created_by, created_at, updated_at
) VALUES
(1, 1, '服用降压药', '降压药', '1片', 'daily', 'ocr', 1, '2024-04-06 08:00:00', 'daily', 'pending', 'elder', NOW(), NOW()),
(2, 3, '服用降压药', '硝苯地平缓释片', '30mg', 'daily', 'ocr', 6, '2024-04-06 08:30:00', 'daily', 'pending', 'elder', NOW(), NOW());

INSERT INTO medical_reminders (
  id, elder_profile_id, title, medical_type, related_event_id,
  source_type, remind_time, repeat_rule, status, created_by, created_at, updated_at
) VALUES
(1, 1, '测量血压', 'examination', 3, 'child_remote', '2024-04-07 19:00:00', 'weekly', 'pending', 'child', NOW(), NOW()),
(2, 1, '复诊提醒', 'review', 2, 'child_remote', '2024-04-15 08:30:00', 'none', 'pending', 'child', NOW(), NOW()),
(3, 2, '测量血糖', 'examination', 4, 'elder_manual', '2024-04-06 07:30:00', 'daily', 'pending', 'elder', NOW(), NOW()),
(4, 2, '内分泌复诊', 'review', 5, 'child_remote', '2024-04-10 13:30:00', 'none', 'pending', 'child', NOW(), NOW()),
(5, 3, '骨密度复查', 'examination', 7, 'child_remote', '2024-08-01 08:30:00', 'none', 'pending', 'child', NOW(), NOW());

-- 生活提醒：喝水 / 锻炼（建议书中提到）
INSERT INTO water_reminders (
  id, elder_profile_id, title,
  daily_target_ml, interval_minutes, per_intake_ml, today_intake_ml, last_intake_time,
  source_type, remind_time, repeat_rule, status, created_by, created_at, updated_at
) VALUES
(1, 1, '喝水提醒', 1600, 60, 200, 400, '2026-04-11 09:30:00', 'elder_manual', '2026-04-11 10:30:00', 'daily', 'pending', 'elder', NOW(), NOW()),
(2, 2, '喝水提醒', 1500, 90, 200, 200, '2026-04-11 09:00:00', 'child_remote', '2026-04-11 10:30:00', 'daily', 'pending', 'child', NOW(), NOW());

INSERT INTO exercise_reminders (
  id, elder_profile_id, title,
  exercise_type, goal_value, goal_unit,
  source_type, remind_time, repeat_rule, status, created_by, created_at, updated_at
) VALUES
(1, 1, '散步锻炼', 'walk', 30, 'minutes', 'child_remote', '2026-04-11 18:00:00', 'daily', 'pending', 'child', NOW(), NOW()),
(2, 3, '太极锻炼', 'taichi', 1, 'times', 'elder_manual', '2026-04-12 08:00:00', 'weekly', 'pending', 'elder', NOW(), NOW());

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
