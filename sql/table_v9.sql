-- ======================================================
-- 智慧养老平台数据库表结构（V9）
-- 在 V8 基础上新增：老人定位守护设置表 elder_location_guard_settings
-- 新建库：先执行本文件，再执行 initial_v9.sql（如需）
-- ======================================================

CREATE DATABASE IF NOT EXISTS elder DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE elder;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS ai_chat_logs;
DROP TABLE IF EXISTS reminder_execution_logs;
DROP TABLE IF EXISTS medical_reminders;
DROP TABLE IF EXISTS exercise_reminders;
DROP TABLE IF EXISTS water_reminders;
DROP TABLE IF EXISTS medicine_reminders;
DROP TABLE IF EXISTS medical_events;
DROP TABLE IF EXISTS medical_records;
DROP TABLE IF EXISTS health_metrics;
DROP TABLE IF EXISTS emergency_alerts;
DROP TABLE IF EXISTS elder_guard_rules;
DROP TABLE IF EXISTS location_logs;
DROP TABLE IF EXISTS activity_logs;
DROP TABLE IF EXISTS geofences;
DROP TABLE IF EXISTS emergency_contacts;
DROP TABLE IF EXISTS family_bindings;
DROP TABLE IF EXISTS elder_location_guard_settings;
DROP TABLE IF EXISTS elder_profiles;
DROP TABLE IF EXISTS notification_settings;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. 用户表（区分老人/子女）
CREATE TABLE users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
  username VARCHAR(50) NOT NULL COMMENT '账号（手机号）',
  password_hash VARCHAR(100) NOT NULL COMMENT '密码哈希',
  role ENUM('elder','child') NOT NULL COMMENT '角色：elder老人/child子女',
  name VARCHAR(30) NOT NULL COMMENT '真实姓名',
  phone VARCHAR(20) NOT NULL COMMENT '手机号',
  avatar_url VARCHAR(255) DEFAULT NULL COMMENT '头像',
  gender ENUM('male','female','unknown') DEFAULT 'unknown' COMMENT '性别',
  birthday DATE DEFAULT NULL COMMENT '生日',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_username (username),
  UNIQUE KEY uk_phone_role (phone, role),
  KEY idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 2. 老人档案（可与账号认领绑定；子女可先建档案）
CREATE TABLE elder_profiles (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '档案ID',
  name VARCHAR(30) NOT NULL COMMENT '姓名',
  phone VARCHAR(20) NOT NULL COMMENT '手机号',
  gender ENUM('male','female','unknown') DEFAULT 'unknown' COMMENT '性别',
  birthday DATE DEFAULT NULL COMMENT '生日',
  claimed_user_id BIGINT DEFAULT NULL COMMENT '认领后的老人用户ID',
  status ENUM('unclaimed','claimed') DEFAULT 'unclaimed' COMMENT '是否已被老人账号认领',
  created_by_child_id BIGINT DEFAULT NULL COMMENT '创建该档案的子女用户ID',
  location_permission_foreground TINYINT(1) NOT NULL DEFAULT 0 COMMENT '前台定位权限是否已授权',
  location_permission_background TINYINT(1) NOT NULL DEFAULT 0 COMMENT '后台定位权限是否已授权',
  permission_updated_at DATETIME DEFAULT NULL COMMENT '最近一次定位权限同步时间',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_phone (phone),
  UNIQUE KEY uk_claimed_user_id (claimed_user_id),
  KEY idx_status (status),
  KEY idx_created_by_child_id (created_by_child_id),
  KEY idx_claimed_permission (claimed_user_id, location_permission_foreground)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人档案表';

-- 2.1. 老人定位守护设置（运行模式/间隔/权限同步等）
CREATE TABLE elder_location_guard_settings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '定位守护设置ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  enabled TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否开启定位守护',
  mode VARCHAR(32) NOT NULL DEFAULT 'off' COMMENT '守护模式：off/foreground/background',
  interval_seconds INT NOT NULL DEFAULT 600 COMMENT '常规定位上传间隔秒数',
  outside_interval_seconds INT NOT NULL DEFAULT 300 COMMENT '外出定位上传间隔秒数',
  background_required TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否要求后台定位能力',
  foreground_granted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '前台定位权限是否已授权',
  background_granted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '后台定位权限是否已授权',
  battery_optimization_ignored TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已忽略电池优化',
  last_started_at DATETIME DEFAULT NULL COMMENT '最近一次启动守护时间',
  last_stopped_at DATETIME DEFAULT NULL COMMENT '最近一次停止守护时间',
  last_upload_at DATETIME DEFAULT NULL COMMENT '最近一次定位上传成功时间',
  last_error VARCHAR(255) DEFAULT NULL COMMENT '最近一次定位守护错误',
  updated_by BIGINT DEFAULT NULL COMMENT '最后更新用户ID',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_elder_location_guard_settings_elder (elder_profile_id),
  KEY idx_enabled_mode (enabled, mode),
  KEY idx_last_upload_at (last_upload_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人定位守护设置表';

-- 3. 家人绑定（档案 <-> 子女账号）
CREATE TABLE family_bindings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '绑定ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  child_user_id BIGINT NOT NULL COMMENT '子女用户ID',
  relation VARCHAR(20) NOT NULL COMMENT '关系',
  is_primary TINYINT(1) DEFAULT 0 COMMENT '是否主监护人',
  status ENUM('pending','active','rejected','removed') DEFAULT 'pending' COMMENT '绑定状态',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_elder_child (elder_profile_id, child_user_id),
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_child_user_id (child_user_id),
  KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='家人绑定关系表';

-- 4. 紧急联系人（V8：增加同一老人手机号唯一约束）
CREATE TABLE emergency_contacts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '联系人ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  name VARCHAR(30) NOT NULL COMMENT '姓名',
  phone VARCHAR(20) NOT NULL COMMENT '电话',
  relation VARCHAR(20) NOT NULL COMMENT '关系',
  priority INT DEFAULT 1 COMMENT '优先级，数字越小越优先',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_elder_phone (elder_profile_id, phone),
  KEY idx_elder_profile_id (elder_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='紧急联系人表';

-- 5. 医疗单据
CREATE TABLE medical_records (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '单据ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  record_type ENUM('prescription','review','examination','case') NOT NULL COMMENT '单据类型',
  image_url VARCHAR(255) NOT NULL COMMENT '图片地址',
  ocr_text TEXT DEFAULT NULL COMMENT 'OCR文本',
  diagnosis VARCHAR(500) DEFAULT NULL COMMENT '诊断',
  visit_time DATETIME DEFAULT NULL COMMENT '就诊时间',
  review_time DATETIME DEFAULT NULL COMMENT '复诊时间',
  remark VARCHAR(500) DEFAULT NULL COMMENT '备注',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_record_type (record_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='医疗单据表';

-- 6. 医疗事件
CREATE TABLE medical_events (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '医疗事件ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  record_id BIGINT DEFAULT NULL COMMENT '关联单据ID',
  title VARCHAR(100) NOT NULL COMMENT '标题',
  event_type ENUM('medicine','review','examination') NOT NULL COMMENT '事件类型',
  event_time DATETIME NOT NULL COMMENT '事件时间',
  repeat_rule VARCHAR(100) DEFAULT 'none' COMMENT '重复规则',
  status ENUM('pending','done','expired') DEFAULT 'pending' COMMENT '状态',
  created_by ENUM('elder','child','ocr') NOT NULL COMMENT '创建来源',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_event_time (event_time),
  KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='医疗事件表';

-- 7. 提醒（V5 思路合入：计划字段 + 执行记录；保留“四表拆分”）
-- 7.1 吃药提醒
CREATE TABLE medicine_reminders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '吃药提醒ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  title VARCHAR(100) NOT NULL COMMENT '标题',
  medicine_name VARCHAR(100) NOT NULL COMMENT '药品名称',
  dosage VARCHAR(50) DEFAULT NULL COMMENT '剂量（如：1片/5ml/2粒）',
  frequency_rule VARCHAR(100) DEFAULT 'none' COMMENT '服用频率（业务语义）',
  source_type ENUM('ocr','elder_manual','child_remote') NOT NULL COMMENT '来源',
  related_event_id BIGINT DEFAULT NULL COMMENT '关联医疗事件ID',
  remind_time DATETIME NOT NULL COMMENT '提醒时间',
  repeat_rule VARCHAR(100) DEFAULT 'none' COMMENT '提醒重复规则（调度）',
  enabled TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
  status ENUM('pending','completed','timeout','cancelled') DEFAULT 'pending' COMMENT '状态',
  created_by ENUM('elder','child') NOT NULL COMMENT '创建人角色',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_remind_time (remind_time),
  KEY idx_status (status),
  KEY idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='吃药提醒表';

-- 7.2 喝水提醒（目标饮水量 + 时段 + 间隔）
CREATE TABLE water_reminders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '喝水提醒ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  title VARCHAR(100) NOT NULL COMMENT '标题',
  daily_target_ml INT NOT NULL DEFAULT 1500 COMMENT '每日目标饮水量(ml)',
  per_intake_ml INT DEFAULT 200 COMMENT '建议单次饮水量(ml)',
  interval_minutes INT NOT NULL DEFAULT 60 COMMENT '提醒间隔(分钟)',
  start_time TIME DEFAULT NULL COMMENT '每日开始时段',
  end_time TIME DEFAULT NULL COMMENT '每日结束时段',
  today_intake_ml INT NOT NULL DEFAULT 0 COMMENT '今日已喝(ml)（MVP：累计值）',
  last_intake_time DATETIME DEFAULT NULL COMMENT '上次喝水时间',
  source_type ENUM('ocr','elder_manual','child_remote') NOT NULL COMMENT '来源',
  remind_time DATETIME NOT NULL COMMENT '下一次提醒时间',
  repeat_rule VARCHAR(100) DEFAULT 'daily' COMMENT '重复规则（喝水一般为每日）',
  enabled TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
  status ENUM('pending','completed','timeout','cancelled') DEFAULT 'pending' COMMENT '状态',
  created_by ENUM('elder','child') NOT NULL COMMENT '创建人角色',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_remind_time (remind_time),
  KEY idx_status (status),
  KEY idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='喝水提醒表';

-- 7.3 锻炼提醒（状态扩展：手动确认/传感器验证/漏做）
CREATE TABLE exercise_reminders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '锻炼提醒ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  title VARCHAR(100) NOT NULL COMMENT '标题',
  exercise_type VARCHAR(50) NOT NULL COMMENT '锻炼类型（如：walk/taichi/baduanjin）',
  goal_value INT DEFAULT NULL COMMENT '目标数值（如：30）',
  goal_unit ENUM('minutes','steps','times') DEFAULT 'minutes' COMMENT '目标单位',
  interval_minutes INT DEFAULT NULL COMMENT '提醒间隔(分钟)',
  start_time TIME DEFAULT NULL COMMENT '每日开始时段',
  end_time TIME DEFAULT NULL COMMENT '每日结束时段',
  source_type ENUM('ocr','elder_manual','child_remote') NOT NULL COMMENT '来源',
  remind_time DATETIME NOT NULL COMMENT '提醒时间',
  repeat_rule VARCHAR(100) DEFAULT 'none' COMMENT '重复规则',
  enabled TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
  status ENUM('pending','completed','timeout','cancelled','self_confirmed','sensor_verified','missed') DEFAULT 'pending' COMMENT '状态',
  created_by ENUM('elder','child') NOT NULL COMMENT '创建人角色',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_remind_time (remind_time),
  KEY idx_status (status),
  KEY idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='锻炼提醒表';

-- 7.4 医疗事项提醒（复诊/检查）
CREATE TABLE medical_reminders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '医疗事项提醒ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  title VARCHAR(100) NOT NULL COMMENT '标题',
  medical_type ENUM('review','examination') NOT NULL COMMENT '医疗事项类型',
  related_event_id BIGINT DEFAULT NULL COMMENT '关联医疗事件ID',
  source_type ENUM('ocr','elder_manual','child_remote') NOT NULL COMMENT '来源',
  remind_time DATETIME NOT NULL COMMENT '提醒时间',
  repeat_rule VARCHAR(100) DEFAULT 'none' COMMENT '重复规则',
  enabled TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
  status ENUM('pending','completed','timeout','cancelled') DEFAULT 'pending' COMMENT '状态',
  created_by ENUM('elder','child') NOT NULL COMMENT '创建人角色',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_remind_time (remind_time),
  KEY idx_status (status),
  KEY idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='医疗事项提醒表';

-- 7.5 执行记录（跨四表：用 reminder_kind + reminder_id 解决 ID 冲突）
CREATE TABLE reminder_execution_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '执行记录ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  reminder_kind ENUM('medicine','water','exercise','medical') NOT NULL COMMENT '提醒类型（对应四表）',
  reminder_id BIGINT NOT NULL COMMENT '对应提醒表的ID',
  scheduled_at DATETIME NOT NULL COMMENT '计划触发时间',
  confirmed_at DATETIME DEFAULT NULL COMMENT '确认完成时间',
  confirm_source ENUM('manual','sensor','system') DEFAULT NULL COMMENT '确认来源',
  is_timeout TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否超时',
  status ENUM('pending','confirmed','missed','timeout','cancelled') NOT NULL DEFAULT 'pending' COMMENT '执行状态',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_reminder (reminder_kind, reminder_id),
  KEY idx_scheduled_at (scheduled_at),
  KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='提醒执行记录表';

-- 8. 健康指标
CREATE TABLE health_metrics (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '指标ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  metric_type ENUM('blood_pressure','blood_sugar','heart_rate','weight') NOT NULL COMMENT '指标类型',
  value VARCHAR(50) NOT NULL COMMENT '指标值',
  unit VARCHAR(20) DEFAULT NULL COMMENT '单位',
  source ENUM('elder_input','child_input','device') NOT NULL COMMENT '来源',
  recorded_at DATETIME NOT NULL COMMENT '记录时间',
  remark VARCHAR(255) DEFAULT NULL COMMENT '备注',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_metric_type (metric_type),
  KEY idx_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='健康指标表';

-- 9. AI 聊天记录
CREATE TABLE ai_chat_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '聊天ID',
  user_id BIGINT NOT NULL COMMENT '操作用户ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  role ENUM('user','assistant') NOT NULL COMMENT '消息角色',
  message TEXT NOT NULL COMMENT '内容',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI医疗助手聊天记录表';

-- 10. 紧急求助
CREATE TABLE emergency_alerts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '求助ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  alert_type ENUM('sos','inactivity','abnormal_location') NOT NULL COMMENT '警报类型',
  trigger_mode ENUM('button','voice','sensor','rule_engine') DEFAULT 'button' COMMENT '触发方式',
  status ENUM('pending_revoke','sent','cancelled','handled','false_alarm') NOT NULL COMMENT '状态',
  trigger_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '触发时间',
  revoke_deadline DATETIME DEFAULT NULL COMMENT '撤回截止时间',
  sent_time DATETIME DEFAULT NULL COMMENT '正式发出时间',
  cancel_time DATETIME DEFAULT NULL COMMENT '取消时间',
  cancel_mode ENUM('button','voice','system') DEFAULT NULL COMMENT '取消方式',
  handled_time DATETIME DEFAULT NULL COMMENT '处理完成时间',
  handled_by BIGINT DEFAULT NULL COMMENT '处理人用户ID',
  location_id BIGINT DEFAULT NULL COMMENT '关联定位记录ID',
  remark VARCHAR(500) DEFAULT NULL COMMENT '备注',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_status (status),
  KEY idx_trigger_time (trigger_time),
  KEY idx_revoke_deadline (revoke_deadline)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='紧急求助记录表';

-- 11. 定位记录（含高德 gaode）
CREATE TABLE location_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '定位ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  location_type ENUM('indoor','outdoor') DEFAULT 'outdoor' COMMENT '室内/室外',
  room_name VARCHAR(50) DEFAULT NULL COMMENT '室内房间名',
  latitude DECIMAL(10,6) NOT NULL COMMENT '纬度',
  longitude DECIMAL(10,6) NOT NULL COMMENT '经度',
  source ENUM('gps','wifi','beacon','sensor','gaode') NOT NULL COMMENT '定位来源',
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_recorded_at (recorded_at),
  KEY idx_elder_recorded_at (elder_profile_id, recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='定位记录表';

-- 12. 活动状态
CREATE TABLE activity_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '活动ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  activity_type ENUM('stationary','moving','go_out','come_home') NOT NULL COMMENT '活动类型',
  start_time DATETIME NOT NULL COMMENT '开始时间',
  end_time DATETIME DEFAULT NULL COMMENT '结束时间',
  duration INT DEFAULT 0 COMMENT '持续秒数',
  is_abnormal TINYINT(1) DEFAULT 0 COMMENT '是否异常',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_is_abnormal (is_abnormal),
  KEY idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='活动状态表';

-- 13. 地理围栏
CREATE TABLE geofences (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '围栏ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  name VARCHAR(50) NOT NULL COMMENT '名称',
  center_latitude DECIMAL(10,6) NOT NULL COMMENT '中心纬度',
  center_longitude DECIMAL(10,6) NOT NULL COMMENT '中心经度',
  radius INT NOT NULL COMMENT '半径(米)',
  is_enabled TINYINT(1) DEFAULT 1 COMMENT '是否启用',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_elder_profile_id (elder_profile_id),
  KEY idx_is_enabled (is_enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='地理围栏表';

-- 14. 守护规则（未活动告警等）
CREATE TABLE elder_guard_rules (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '规则ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  enabled TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
  active_start_time TIME NOT NULL COMMENT '监控开始时刻',
  active_end_time TIME NOT NULL COMMENT '监控结束时刻',
  home_inactivity_minutes INT NOT NULL DEFAULT 120 COMMENT '在家未活动阈值(分钟)',
  outside_inactivity_minutes INT NOT NULL DEFAULT 60 COMMENT '外出未活动阈值(分钟)',
  alert_min_interval_minutes INT NOT NULL DEFAULT 120 COMMENT '同类告警最小间隔(分钟)',
  created_by_user_id BIGINT DEFAULT NULL COMMENT '创建人',
  updated_by_user_id BIGINT DEFAULT NULL COMMENT '更新人',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_guard_rule_elder_profile_id (elder_profile_id),
  KEY idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人守护规则表';

-- 15. 子女通知设置
CREATE TABLE notification_settings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '设置ID',
  child_user_id BIGINT NOT NULL COMMENT '子女用户ID',
  warning_push_enabled TINYINT(1) DEFAULT 1 COMMENT '异常预警推送',
  sos_push_enabled TINYINT(1) DEFAULT 1 COMMENT 'SOS推送',
  reminder_sync_enabled TINYINT(1) DEFAULT 1 COMMENT '提醒同步推送',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_child_user_id (child_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='子女通知设置表';

SET FOREIGN_KEY_CHECKS = 1;
