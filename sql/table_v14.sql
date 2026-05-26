-- ======================================================
-- 智慧养老平台数据库表结构（V14）
-- 在 V13 基础上调整兴趣社群群聊，对齐 docs/兴趣社群-老人端群聊-OpenAPI.md：
--   1) interest_community_messages 增加 image 类型与 image_url
--   2) 新增 interest_community_chat_clear（按用户视角软清空，不删群消息）
--   3) direct_messages 同步支持 image（私聊与群聊一致）
-- V13 已有：interest_communities、memberships、messages、peer_seed、friends、direct_* 等
-- 知识库数据请用后端导入任务或 CSV 自行导入，勿将全量 INSERT 提交进 Git
-- 新建库：先执行本文件，再执行 initial_v14.sql（如需）
-- 自 V13 升级：可仅执行文末「V13 → V14 迁移」段（ALTER + 新表）
-- ======================================================

CREATE DATABASE IF NOT EXISTS elder DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE elder;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 先删兴趣社群子表
DROP TABLE IF EXISTS direct_messages;
DROP TABLE IF EXISTS direct_message_threads;
DROP TABLE IF EXISTS elder_friends;
DROP TABLE IF EXISTS interest_community_chat_clear;
DROP TABLE IF EXISTS interest_community_messages;
DROP TABLE IF EXISTS community_peer_seed_log;
DROP TABLE IF EXISTS interest_community_memberships;
DROP TABLE IF EXISTS community_demo_peer_profiles;
DROP TABLE IF EXISTS interest_communities;

-- 先删 AI 子表再删父表（无语义外键，仅保证与 Navicat 习惯一致）
DROP TABLE IF EXISTS ai_consultation_message;
DROP TABLE IF EXISTS ai_family_notification;
DROP TABLE IF EXISTS ai_feedback;
DROP TABLE IF EXISTS ai_manual_handoff;
DROP TABLE IF EXISTS ai_preconsultation_record;
DROP TABLE IF EXISTS ai_consultation;
DROP TABLE IF EXISTS ai_knowledge_import_job;
DROP TABLE IF EXISTS ai_training_job;
DROP TABLE IF EXISTS ai_medical_qa_knowledge;
DROP TABLE IF EXISTS ai_medical_risk_rule;

DROP TABLE IF EXISTS ai_chat_logs;
DROP TABLE IF EXISTS reminder_execution_logs;
DROP TABLE IF EXISTS medical_reminders;
DROP TABLE IF EXISTS exercise_reminders;
DROP TABLE IF EXISTS water_reminders;
DROP TABLE IF EXISTS medicine_reminders;
DROP TABLE IF EXISTS medical_calendar_events;
DROP TABLE IF EXISTS medical_documents;
DROP TABLE IF EXISTS medical_archive_folders;
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

-- 5.1 医疗 OCR 归档 — 病情 / 分类文件夹（后端 MedicalArchiveFolder）
CREATE TABLE medical_archive_folders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '文件夹ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  name VARCHAR(128) NOT NULL COMMENT '文件夹名称',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_med_folder_elder (elder_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='医疗归档文件夹表';

-- 5.2 医疗 OCR 归档 — 单据快照（后端 MedicalDocument）
CREATE TABLE medical_documents (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '归档单据ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  uploaded_by_user_id BIGINT NOT NULL COMMENT '上传用户ID',
  folder_id BIGINT DEFAULT NULL COMMENT '所属文件夹ID',
  title VARCHAR(256) DEFAULT NULL COMMENT '标题摘要',
  original_filename VARCHAR(512) DEFAULT NULL COMMENT '原始文件名',
  stored_path VARCHAR(1024) NOT NULL COMMENT '服务端存储相对路径',
  content_type VARCHAR(128) DEFAULT NULL COMMENT '图片 MIME',
  doc_category VARCHAR(64) DEFAULT NULL COMMENT '推断类别 LAB_REPORT/PRESCRIPTION等',
  routed_specialized_api VARCHAR(64) DEFAULT NULL COMMENT '百度云结构化接口标识',
  structured_route_source VARCHAR(32) DEFAULT NULL COMMENT '路由来源 keyword_text/doc_classify',
  structured_error VARCHAR(512) DEFAULT NULL COMMENT '结构化失败原因',
  full_text MEDIUMTEXT COMMENT 'OCR 全文',
  ocr_raw_json LONGTEXT COMMENT '高精度 OCR 原始 JSON',
  classify_raw_json LONGTEXT COMMENT '文档分类原始 JSON',
  specialized_raw_json LONGTEXT COMMENT '医疗结构化原始 JSON',
  display_blocks_json LONGTEXT COMMENT '前端结构化展示块 JSON',
  structured_fields_json LONGTEXT COMMENT '扁平化结构化字段 JSON',
  extracted_fields_json LONGTEXT COMMENT '启发式抽取字段 JSON',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_med_doc_elder_created (elder_profile_id, created_at),
  KEY idx_med_doc_folder (folder_id),
  CONSTRAINT fk_med_doc_folder FOREIGN KEY (folder_id) REFERENCES medical_archive_folders (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='医疗OCR归档单据表';

-- 5.3 医疗日历事件（后端 MedicalCalendarEvent，事件类型 EXAM/FOLLOWUP/MEDICATION）
CREATE TABLE medical_calendar_events (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '日历事件ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID',
  event_type VARCHAR(32) NOT NULL COMMENT 'EXAM检查 FOLLOWUP复诊 MEDICATION用药',
  title VARCHAR(256) NOT NULL COMMENT '标题',
  start_at DATETIME NOT NULL COMMENT '开始时间',
  end_at DATETIME DEFAULT NULL COMMENT '结束时间',
  notes VARCHAR(1024) DEFAULT NULL COMMENT '备注',
  source_document_id BIGINT DEFAULT NULL COMMENT '来源归档单据ID',
  created_by_user_id BIGINT NOT NULL COMMENT '创建人用户ID',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_med_cal_elder_start (elder_profile_id, start_at),
  CONSTRAINT fk_med_cal_doc FOREIGN KEY (source_document_id) REFERENCES medical_documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='医疗提醒日历事件表';

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

-- 9.1 AI 高危症状规则表（逻辑关联 ai_consultation.matched_rule_id）
CREATE TABLE ai_medical_risk_rule (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
  rule_name TEXT NOT NULL COMMENT '规则名称',
  keywords TEXT NOT NULL COMMENT '命中关键词，逗号分隔',
  risk_level VARCHAR(20) NOT NULL DEFAULT 'high' COMMENT '风险等级：low/medium/high/emergency',
  warning_message TEXT NOT NULL COMMENT '风险提示文案',
  recommended_action TEXT NOT NULL COMMENT '建议动作',
  recommended_department_id BIGINT DEFAULT NULL COMMENT '推荐科室ID（逻辑关联）',
  need_family_notify TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否通知家属',
  need_emergency_call TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否提示紧急呼叫',
  status VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT '状态：active/inactive',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_medical_risk_rule_status (status),
  KEY idx_ai_medical_risk_rule_risk_level (risk_level),
  KEY idx_ai_medical_risk_rule_department_id (recommended_department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 高危症状规则表';

-- 9.2 AI 医疗问答知识库（大数据请用导入任务写入）
CREATE TABLE ai_medical_qa_knowledge (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
  question TEXT NOT NULL COMMENT '标准问题',
  answer TEXT NOT NULL COMMENT '标准答案',
  question_keywords TEXT DEFAULT NULL COMMENT '问题关键词，逗号分隔',
  answer_summary TEXT DEFAULT NULL COMMENT '答案摘要',
  disease_tag TEXT DEFAULT NULL COMMENT '疾病标签',
  symptom_tag TEXT DEFAULT NULL COMMENT '症状标签',
  scene_tag TEXT DEFAULT NULL COMMENT '场景标签，如老人端/家属端/慢病',
  risk_level VARCHAR(20) NOT NULL DEFAULT 'low' COMMENT '风险等级：low/medium/high/emergency',
  department_id BIGINT DEFAULT NULL COMMENT '推荐科室ID（逻辑关联）',
  source TEXT DEFAULT NULL COMMENT '数据来源：数据集/人工整理/审核导入',
  status VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT '状态：active/inactive',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_medical_qa_knowledge_status (status),
  KEY idx_ai_medical_qa_knowledge_risk_level (risk_level),
  KEY idx_ai_medical_qa_knowledge_department_id (department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 医疗问答知识库表';

-- 9.3 AI 知识库导入任务
CREATE TABLE ai_knowledge_import_job (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '知识库导入任务ID',
  file_name TEXT NOT NULL COMMENT '导入文件名',
  file_path TEXT NOT NULL COMMENT '导入文件路径',
  import_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '导入状态：pending/running/success/failed',
  total_rows INT NOT NULL DEFAULT 0 COMMENT '总行数',
  success_rows INT NOT NULL DEFAULT 0 COMMENT '成功行数',
  failed_rows INT NOT NULL DEFAULT 0 COMMENT '失败行数',
  error_message TEXT DEFAULT NULL COMMENT '错误信息',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_knowledge_import_job_status (import_status),
  KEY idx_ai_knowledge_import_job_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 知识库导入任务表';

-- 9.4 AI 训练 / 检索索引构建任务
CREATE TABLE ai_training_job (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '训练/索引构建任务ID',
  algorithm TEXT NOT NULL COMMENT '算法名称：TF-IDF/word2vec/sentence-transformer等',
  status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '任务状态：pending/running/success/failed',
  total_samples INT NOT NULL DEFAULT 0 COMMENT '总样本数',
  valid_samples INT NOT NULL DEFAULT 0 COMMENT '有效样本数',
  duplicate_samples INT NOT NULL DEFAULT 0 COMMENT '重复样本数',
  index_path TEXT DEFAULT NULL COMMENT '索引文件路径',
  started_at DATETIME DEFAULT NULL COMMENT '开始时间',
  finished_at DATETIME DEFAULT NULL COMMENT '结束时间',
  duration_ms BIGINT DEFAULT NULL COMMENT '耗时毫秒',
  error_message TEXT DEFAULT NULL COMMENT '错误信息',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_training_job_status (status),
  KEY idx_ai_training_job_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 训练/检索索引构建任务表';

-- 9.5 AI 咨询主记录（与 elder_profiles / users 逻辑关联）
CREATE TABLE ai_consultation (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '咨询主记录ID',
  user_id BIGINT NOT NULL COMMENT '发起咨询用户ID（逻辑关联 users.id）',
  elderly_id BIGINT NOT NULL COMMENT '老人档案ID（逻辑关联 elder_profiles.id）',
  input_text TEXT NOT NULL COMMENT '用户原始输入文本',
  input_type VARCHAR(20) NOT NULL DEFAULT 'text' COMMENT '输入类型：text/voice',
  normalized_text TEXT DEFAULT NULL COMMENT '归一化后的文本',
  risk_level VARCHAR(20) NOT NULL DEFAULT 'low' COMMENT '风险等级：low/medium/high/emergency',
  matched_rule_id BIGINT DEFAULT NULL COMMENT '命中的高危规则ID（逻辑关联 ai_medical_risk_rule.id）',
  recommended_department_id BIGINT DEFAULT NULL COMMENT '推荐科室ID（逻辑关联 departments.id，可空）',
  recommended_doctor_id BIGINT DEFAULT NULL COMMENT '推荐医生ID（逻辑关联 doctors.id，可空）',
  appointment_id BIGINT DEFAULT NULL COMMENT '关联挂号ID（逻辑关联 appointments.id，可空）',
  need_medical_visit TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否建议线下就医',
  need_family_notify TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否需要同步家属',
  final_answer TEXT DEFAULT NULL COMMENT '最终展示给用户的回答',
  follow_up_question TEXT DEFAULT NULL COMMENT '追问',
  status VARCHAR(20) NOT NULL DEFAULT 'processing' COMMENT '状态：processing/done/closed/need_more_info 等',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  recommended_department_name VARCHAR(255) DEFAULT NULL COMMENT '推荐科室名称',
  safety_notice TEXT DEFAULT NULL COMMENT '安全提示',
  KEY idx_ai_consultation_elderly_id (elderly_id),
  KEY idx_ai_consultation_user_id (user_id),
  KEY idx_ai_consultation_risk_level (risk_level),
  KEY idx_ai_consultation_status (status),
  KEY idx_ai_consultation_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 咨询主记录表';

-- 9.6 AI 咨询多轮消息
CREATE TABLE ai_consultation_message (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '消息ID',
  consultation_id BIGINT NOT NULL COMMENT '咨询主记录ID（逻辑关联 ai_consultation.id）',
  sender_type TEXT NOT NULL COMMENT '发送方类型：user/assistant/system',
  message_content TEXT NOT NULL COMMENT '消息内容',
  message_type VARCHAR(20) NOT NULL DEFAULT 'text' COMMENT '消息类型：text/voice/rule/llm',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  KEY idx_ai_consultation_message_consultation_id (consultation_id),
  KEY idx_ai_consultation_message_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 咨询多轮消息表';

-- 9.7 AI 家属同步记录
CREATE TABLE ai_family_notification (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '家属同步记录ID',
  consultation_id BIGINT NOT NULL COMMENT '咨询主记录ID（逻辑关联 ai_consultation.id）',
  elderly_id BIGINT NOT NULL COMMENT '老人档案ID（逻辑关联 elder_profiles.id）',
  family_user_id BIGINT NOT NULL COMMENT '家属用户ID（逻辑关联 users.id）',
  notification_type TEXT NOT NULL COMMENT '通知类型：risk/consultation/summary',
  content TEXT NOT NULL COMMENT '同步内容',
  send_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '发送状态：pending/sent/failed',
  read_status VARCHAR(20) NOT NULL DEFAULT 'unread' COMMENT '阅读状态：unread/read',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  read_at DATETIME DEFAULT NULL COMMENT '阅读时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_family_notification_elderly_id (elderly_id),
  KEY idx_ai_family_notification_family_user_id (family_user_id),
  KEY idx_ai_family_notification_consultation_id (consultation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 家属同步记录表';

-- 9.8 AI 咨询反馈
CREATE TABLE ai_feedback (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '反馈ID',
  consultation_id BIGINT NOT NULL COMMENT '咨询主记录ID（逻辑关联 ai_consultation.id）',
  user_id BIGINT NOT NULL COMMENT '反馈用户ID（逻辑关联 users.id）',
  feedback_type TEXT NOT NULL COMMENT '反馈类型：helpful/not_helpful/visited_doctor/need_human',
  feedback_text TEXT DEFAULT NULL COMMENT '反馈文本',
  is_helpful TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否有帮助',
  has_visited_doctor TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已就医',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_feedback_consultation_id (consultation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 咨询反馈表';

-- 9.9 AI 人工兜底记录
CREATE TABLE ai_manual_handoff (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '人工兜底记录ID',
  consultation_id BIGINT NOT NULL COMMENT '咨询主记录ID（逻辑关联 ai_consultation.id）',
  user_id BIGINT NOT NULL COMMENT '发起用户ID（逻辑关联 users.id）',
  reason TEXT NOT NULL COMMENT '兜底原因',
  handoff_type VARCHAR(50) NOT NULL DEFAULT 'visit' COMMENT '兜底类型：visit/customer_service/doctor',
  status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '状态：pending/handled/closed',
  handled_by BIGINT DEFAULT NULL COMMENT '处理人用户ID（逻辑关联 users.id）',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_manual_handoff_consultation_id (consultation_id),
  KEY idx_ai_manual_handoff_user_id (user_id),
  KEY idx_ai_manual_handoff_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 人工兜底记录表';

-- 9.10 AI 预问诊记录
CREATE TABLE ai_preconsultation_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '预问诊记录ID',
  consultation_id BIGINT NOT NULL COMMENT '咨询主记录ID（逻辑关联 ai_consultation.id）',
  elderly_id BIGINT NOT NULL COMMENT '老人档案ID（逻辑关联 elder_profiles.id）',
  chief_complaint TEXT DEFAULT NULL COMMENT '主诉',
  symptom_duration TEXT DEFAULT NULL COMMENT '症状持续时间',
  accompanied_symptoms TEXT DEFAULT NULL COMMENT '伴随症状',
  medical_history TEXT DEFAULT NULL COMMENT '既往史',
  medication_history TEXT DEFAULT NULL COMMENT '用药史',
  allergy_history TEXT DEFAULT NULL COMMENT '过敏史',
  summary TEXT DEFAULT NULL COMMENT '预问诊摘要',
  recommended_department_id BIGINT DEFAULT NULL COMMENT '推荐科室ID（逻辑关联 departments.id）',
  risk_level VARCHAR(20) NOT NULL DEFAULT 'low' COMMENT '风险等级：low/medium/high/emergency',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_ai_preconsultation_record_consultation_id (consultation_id),
  KEY idx_ai_preconsultation_record_elderly_id (elderly_id),
  KEY idx_ai_preconsultation_record_department_id (recommended_department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI 预问诊记录表';

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


-- 16. 兴趣社群目录（前端 CommunityCatalog）
CREATE TABLE interest_communities (
  id VARCHAR(32) PRIMARY KEY COMMENT '社群标识，如 taiji/calligraphy/fitness/travel',
  name VARCHAR(64) NOT NULL COMMENT '社群名称',
  short_description VARCHAR(512) NOT NULL COMMENT '简介',
  preview_icon VARCHAR(16) NOT NULL COMMENT '列表图标 emoji',
  member_hint VARCHAR(64) DEFAULT '' COMMENT '成员规模展示文案',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
  is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否开放',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_sort_active (sort_order, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群目录表';

-- 16.1 演示群友 / 可发现好友目录（前端 FriendDiscoverCatalog）
CREATE TABLE community_demo_peer_profiles (
  scope_key VARCHAR(64) PRIMARY KEY COMMENT '演示 scopeKey，如 demo_peer_wang',
  display_name VARCHAR(64) NOT NULL COMMENT '展示姓名',
  phone VARCHAR(20) NOT NULL COMMENT '演示手机号',
  hint VARCHAR(255) DEFAULT '' COMMENT '推荐说明',
  emoji VARCHAR(16) DEFAULT NULL COMMENT '默认头像 emoji',
  linked_elder_profile_id BIGINT DEFAULT NULL COMMENT '若映射真实老人档案',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_demo_peer_phone (phone),
  KEY idx_demo_peer_linked_elder (linked_elder_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群演示群友目录表';

-- 16.2 老人入群记录（前端 CommunityMembershipRepository）
CREATE TABLE interest_community_memberships (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '成员关系ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID（逻辑关联 elder_profiles.id）',
  community_id VARCHAR(32) NOT NULL COMMENT '社群ID（逻辑关联 interest_communities.id）',
  scope_key VARCHAR(64) NOT NULL COMMENT '入群时 scopeKey，如 phone_13800138001',
  status ENUM('active','left') NOT NULL DEFAULT 'active' COMMENT '成员状态',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入群时间',
  left_at DATETIME DEFAULT NULL COMMENT '退群时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_elder_community (elder_profile_id, community_id),
  KEY idx_community_status (community_id, status),
  KEY idx_membership_scope (scope_key),
  KEY idx_membership_elder_status (elder_profile_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群成员关系表';

-- 16.3 群聊消息（对齐 POST/GET .../interest-communities/{id}/messages）
CREATE TABLE interest_community_messages (
  id VARCHAR(64) PRIMARY KEY COMMENT '消息ID',
  community_id VARCHAR(32) NOT NULL COMMENT '社群ID（逻辑关联 interest_communities.id）',
  sender_scope_key VARCHAR(64) NOT NULL COMMENT '发送者 scopeKey；system 为群助手',
  sender_elder_profile_id BIGINT DEFAULT NULL COMMENT '发送者老人档案ID（系统消息为空）',
  sender_display_name VARCHAR(64) NOT NULL COMMENT '气泡展示名',
  sender_role ENUM('elder','child') NOT NULL DEFAULT 'elder' COMMENT '发送角色',
  message_kind ENUM('voice','text','image') NOT NULL DEFAULT 'text' COMMENT '消息类型：语音/文字/图片',
  text_content TEXT DEFAULT NULL COMMENT '文字内容（kind=text 时）',
  audio_url VARCHAR(512) DEFAULT NULL COMMENT '语音 URL（kind=voice；GET /v1/community-voice/{id}/file）',
  image_url VARCHAR(512) DEFAULT NULL COMMENT '图片 URL（kind=image；GET /v1/community-image/{id}/file）',
  duration_ms INT NOT NULL DEFAULT 0 COMMENT '语音时长毫秒（kind=voice）',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  KEY idx_comm_msg_community_created (community_id, created_at),
  KEY idx_comm_msg_sender_scope (sender_scope_key),
  KEY idx_comm_msg_sender_elder (sender_elder_profile_id),
  KEY idx_comm_msg_kind (message_kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群群聊消息表';

-- 16.3.1 群聊清空记录（DELETE .../messages 软清空，按查看者 scope 隐藏历史）
CREATE TABLE interest_community_chat_clear (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '记录ID',
  viewer_scope_key VARCHAR(64) NOT NULL COMMENT '查看者 scopeKey：老人 phone_xxx / 子女 child_preview_{elderScope}',
  viewer_user_id BIGINT DEFAULT NULL COMMENT '操作者 users.id（老人或子女；便于审计）',
  elder_profile_id BIGINT NOT NULL COMMENT '所属老人档案ID（群归属；子女预览时为父母档案）',
  community_id VARCHAR(32) NOT NULL COMMENT '社群ID',
  clear_before_millis BIGINT NOT NULL COMMENT '此时间及前的消息对该查看者不可见（毫秒时间戳）',
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '最近清空时间',
  UNIQUE KEY uk_clear_viewer_community (viewer_scope_key, community_id),
  KEY idx_clear_elder_community (elder_profile_id, community_id),
  KEY idx_clear_viewer_user (viewer_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群群聊清空记录（按用户视角，不删消息行）';

-- 16.4 演示群友消息播种标记（前端 interest_comm_peer_seeded_v1_{communityId}）
CREATE TABLE community_peer_seed_log (
  community_id VARCHAR(32) PRIMARY KEY COMMENT '社群ID',
  seeded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '播种时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群演示消息播种记录表';

-- 16.5 老人好友（前端 CommunityFriendRepository，单向通讯录）
CREATE TABLE elder_friends (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '好友记录ID',
  owner_elder_profile_id BIGINT NOT NULL COMMENT '好友列表拥有者档案ID',
  owner_scope_key VARCHAR(64) NOT NULL COMMENT '拥有者 scopeKey',
  friend_scope_key VARCHAR(64) NOT NULL COMMENT '好友 scopeKey',
  friend_elder_profile_id BIGINT DEFAULT NULL COMMENT '好友档案ID（若已注册）',
  display_name VARCHAR(64) NOT NULL COMMENT '展示姓名',
  phone VARCHAR(20) NOT NULL COMMENT '手机号',
  hint VARCHAR(255) DEFAULT '' COMMENT '来源说明',
  emoji VARCHAR(16) DEFAULT '👤' COMMENT '默认头像 emoji',
  added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
  UNIQUE KEY uk_owner_friend_scope (owner_elder_profile_id, friend_scope_key),
  UNIQUE KEY uk_owner_friend_phone (owner_elder_profile_id, phone),
  KEY idx_friends_owner_added (owner_elder_profile_id, added_at),
  KEY idx_friends_friend_scope (friend_scope_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人好友表';

-- 16.6 一对一私聊线程（前端 CommunityDirectRepository 线程键）
CREATE TABLE direct_message_threads (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '私聊线程ID',
  participant_a_scope_key VARCHAR(64) NOT NULL COMMENT '字典序较小 scopeKey',
  participant_b_scope_key VARCHAR(64) NOT NULL COMMENT '字典序较大 scopeKey',
  participant_a_elder_profile_id BIGINT DEFAULT NULL COMMENT '参与者 A 档案ID',
  participant_b_elder_profile_id BIGINT DEFAULT NULL COMMENT '参与者 B 档案ID',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最近消息时间',
  UNIQUE KEY uk_direct_thread_participants (participant_a_scope_key, participant_b_scope_key),
  KEY idx_direct_thread_a (participant_a_elder_profile_id),
  KEY idx_direct_thread_b (participant_b_elder_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人一对一私聊线程表';

-- 16.7 私聊消息（message_kind 与群聊对齐，便于后续扩展图片）
CREATE TABLE direct_messages (
  id VARCHAR(64) PRIMARY KEY COMMENT '消息ID',
  thread_id BIGINT NOT NULL COMMENT '线程ID（逻辑关联 direct_message_threads.id）',
  sender_scope_key VARCHAR(64) NOT NULL COMMENT '发送者 scopeKey',
  sender_elder_profile_id BIGINT DEFAULT NULL COMMENT '发送者档案ID',
  sender_display_name VARCHAR(64) NOT NULL COMMENT '展示姓名',
  sender_role ENUM('elder','child') NOT NULL DEFAULT 'elder' COMMENT '发送角色',
  message_kind ENUM('voice','text','image') NOT NULL DEFAULT 'voice' COMMENT '消息类型',
  text_content TEXT DEFAULT NULL COMMENT '文字内容',
  audio_url VARCHAR(512) DEFAULT NULL COMMENT '语音文件 URL',
  image_url VARCHAR(512) DEFAULT NULL COMMENT '图片 URL',
  duration_ms INT NOT NULL DEFAULT 0 COMMENT '语音时长毫秒',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  KEY idx_direct_msg_thread_created (thread_id, created_at),
  KEY idx_direct_msg_sender_scope (sender_scope_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人一对一私聊消息表';

SET FOREIGN_KEY_CHECKS = 1;

-- ======================================================
-- V13 → V14 迁移（已有 V13 库时单独执行本段即可）
-- ======================================================
-- USE elder;
--
-- ALTER TABLE interest_community_messages
--   MODIFY message_kind ENUM('voice','text','image') NOT NULL DEFAULT 'text' COMMENT '消息类型：语音/文字/图片',
--   ADD COLUMN image_url VARCHAR(512) DEFAULT NULL COMMENT '图片 URL' AFTER audio_url;
--
-- CREATE TABLE IF NOT EXISTS interest_community_chat_clear (
--   id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '记录ID',
--   viewer_scope_key VARCHAR(64) NOT NULL COMMENT '查看者 scopeKey',
--   viewer_user_id BIGINT DEFAULT NULL COMMENT '操作者 users.id',
--   elder_profile_id BIGINT NOT NULL COMMENT '所属老人档案ID',
--   community_id VARCHAR(32) NOT NULL COMMENT '社群ID',
--   clear_before_millis BIGINT NOT NULL COMMENT '此时间及前的消息对该查看者不可见',
--   updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
--   UNIQUE KEY uk_clear_viewer_community (viewer_scope_key, community_id),
--   KEY idx_clear_elder_community (elder_profile_id, community_id),
--   KEY idx_clear_viewer_user (viewer_user_id)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群群聊清空记录';
--
-- ALTER TABLE direct_messages
--   MODIFY message_kind ENUM('voice','text','image') NOT NULL DEFAULT 'voice' COMMENT '消息类型',
--   ADD COLUMN image_url VARCHAR(512) DEFAULT NULL COMMENT '图片 URL' AFTER audio_url;
