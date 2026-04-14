-- ======================================================
-- 从「最初版」schema（elder_id / child_id）升级到融合版（V4）
-- 特点：可重复执行；已升级库会自动跳过；不 TRUNCATE、不 DROP 业务表
--
-- 使用方式：
--   mysql -u... -p elder < sql/migrate_legacy_to_v4.sql
--
-- 约定：旧库中各表的 elder_id 表示「老人用户 users.id」，且与 V4 中
--       elder_profiles.id 一一对应（迁移脚本按 users.id 插入档案主键）。
-- ======================================================

USE elder;
SET NAMES utf8mb4;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_migrate_legacy_elder_to_v4 $$
CREATE PROCEDURE sp_migrate_legacy_elder_to_v4()
BEGIN
  DECLARE v_db VARCHAR(64);
  DECLARE v_has_elder_profiles INT DEFAULT 0;
  DECLARE v_col INT DEFAULT 0;

  SET v_db = DATABASE();

  -- ---------- 1. elder_profiles ----------
  SELECT COUNT(*) INTO v_has_elder_profiles
  FROM information_schema.tables
  WHERE table_schema = v_db AND table_name = 'elder_profiles';

  IF v_has_elder_profiles = 0 THEN
    CREATE TABLE elder_profiles (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      name VARCHAR(30) NOT NULL,
      phone VARCHAR(20) NOT NULL,
      gender ENUM('male','female','unknown') DEFAULT 'unknown',
      birthday DATE DEFAULT NULL,
      claimed_user_id BIGINT DEFAULT NULL,
      status ENUM('unclaimed','claimed') DEFAULT 'unclaimed',
      created_by_child_id BIGINT DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uk_phone (phone),
      UNIQUE KEY uk_claimed_user_id (claimed_user_id),
      KEY idx_status (status),
      KEY idx_created_by_child_id (created_by_child_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  END IF;

  -- 为每位老人用户补一条档案，主键 id = users.id，保证原 elder_id 可直接当作 elder_profile_id
  INSERT INTO elder_profiles (id, name, phone, gender, birthday, claimed_user_id, status, created_by_child_id, created_at, updated_at)
  SELECT u.id, u.name, u.phone, u.gender, u.birthday, u.id, 'claimed', NULL, NOW(), NOW()
  FROM users u
  WHERE u.role = 'elder'
    AND NOT EXISTS (SELECT 1 FROM elder_profiles ep WHERE ep.id = u.id);

  -- ---------- 2. elder_guard_rules ----------
  SELECT COUNT(*) INTO v_col
  FROM information_schema.tables
  WHERE table_schema = v_db AND table_name = 'elder_guard_rules';
  IF v_col = 0 THEN
    CREATE TABLE elder_guard_rules (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      elder_profile_id BIGINT NOT NULL,
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      active_start_time TIME NOT NULL,
      active_end_time TIME NOT NULL,
      home_inactivity_minutes INT NOT NULL DEFAULT 120,
      outside_inactivity_minutes INT NOT NULL DEFAULT 60,
      alert_min_interval_minutes INT NOT NULL DEFAULT 120,
      created_by_user_id BIGINT DEFAULT NULL,
      updated_by_user_id BIGINT DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uk_guard_rule_elder_profile_id (elder_profile_id),
      KEY idx_enabled (enabled)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  END IF;

  -- ---------- 3. users：uk_phone_role ----------
  SELECT COUNT(*) INTO v_col
  FROM information_schema.statistics
  WHERE table_schema = v_db AND table_name = 'users' AND index_name = 'uk_phone_role';
  IF v_col = 0 THEN
    ALTER TABLE users ADD UNIQUE KEY uk_phone_role (phone, role);
  END IF;

  -- ---------- 4. family_bindings（elder_id/child_id -> V4）----------
  SELECT COUNT(*) INTO v_col
  FROM information_schema.columns
  WHERE table_schema = v_db AND table_name = 'family_bindings' AND column_name = 'elder_id';
  IF v_col > 0 THEN
    SELECT COUNT(*) INTO v_col
    FROM information_schema.columns
    WHERE table_schema = v_db AND table_name = 'family_bindings' AND column_name = 'elder_profile_id';
    IF v_col = 0 THEN
      ALTER TABLE family_bindings
        ADD COLUMN elder_profile_id BIGINT NULL AFTER id,
        ADD COLUMN child_user_id BIGINT NULL AFTER elder_profile_id,
        ADD COLUMN status ENUM('pending','active','rejected','removed') DEFAULT 'active' AFTER is_primary,
        ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at;
      UPDATE family_bindings SET
        elder_profile_id = elder_id,
        child_user_id = child_id,
        status = 'active',
        updated_at = COALESCE(created_at, NOW());
      ALTER TABLE family_bindings
        MODIFY elder_profile_id BIGINT NOT NULL,
        MODIFY child_user_id BIGINT NOT NULL;
      ALTER TABLE family_bindings
        DROP COLUMN elder_id,
        DROP COLUMN child_id;
      ALTER TABLE family_bindings
        ADD UNIQUE KEY uk_elder_child (elder_profile_id, child_user_id),
        ADD KEY idx_elder_profile_id (elder_profile_id),
        ADD KEY idx_child_user_id (child_user_id),
        ADD KEY idx_status (status);
    END IF;
  END IF;

  -- ---------- 5. 通用：表名 T 上 elder_id -> elder_profile_id ----------
  -- notification_settings：child_id -> child_user_id
  SELECT COUNT(*) INTO v_col
  FROM information_schema.columns
  WHERE table_schema = v_db AND table_name = 'notification_settings' AND column_name = 'child_id';
  IF v_col > 0 THEN
    SELECT COUNT(*) INTO v_col
    FROM information_schema.columns
    WHERE table_schema = v_db AND table_name = 'notification_settings' AND column_name = 'child_user_id';
    IF v_col = 0 THEN
      ALTER TABLE notification_settings ADD COLUMN child_user_id BIGINT NULL AFTER id;
      UPDATE notification_settings SET child_user_id = child_id;
      ALTER TABLE notification_settings MODIFY child_user_id BIGINT NOT NULL;
      ALTER TABLE notification_settings DROP COLUMN child_id;
      -- 替换唯一索引名
      ALTER TABLE notification_settings DROP INDEX uk_child_id;
      ALTER TABLE notification_settings ADD UNIQUE KEY uk_child_user_id (child_user_id);
    END IF;
  END IF;

  -- emergency_contacts
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='emergency_contacts' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='emergency_contacts' AND column_name='elder_profile_id') THEN
    ALTER TABLE emergency_contacts ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE emergency_contacts SET elder_profile_id = elder_id;
    ALTER TABLE emergency_contacts MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE emergency_contacts DROP COLUMN elder_id;
    ALTER TABLE emergency_contacts ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- medical_records
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='medical_records' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='medical_records' AND column_name='elder_profile_id') THEN
    ALTER TABLE medical_records ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE medical_records SET elder_profile_id = elder_id;
    ALTER TABLE medical_records MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE medical_records DROP COLUMN elder_id;
    ALTER TABLE medical_records ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- medical_events
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='medical_events' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='medical_events' AND column_name='elder_profile_id') THEN
    ALTER TABLE medical_events ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE medical_events SET elder_profile_id = elder_id;
    ALTER TABLE medical_events MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE medical_events DROP COLUMN elder_id;
    ALTER TABLE medical_events ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- reminders
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='reminders' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='reminders' AND column_name='elder_profile_id') THEN
    ALTER TABLE reminders ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE reminders SET elder_profile_id = elder_id;
    ALTER TABLE reminders MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE reminders DROP COLUMN elder_id;
    ALTER TABLE reminders ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- health_metrics
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='health_metrics' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='health_metrics' AND column_name='elder_profile_id') THEN
    ALTER TABLE health_metrics ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE health_metrics SET elder_profile_id = elder_id;
    ALTER TABLE health_metrics MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE health_metrics DROP COLUMN elder_id;
    ALTER TABLE health_metrics ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- ai_chat_logs
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='ai_chat_logs' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='ai_chat_logs' AND column_name='elder_profile_id') THEN
    ALTER TABLE ai_chat_logs ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE ai_chat_logs SET elder_profile_id = elder_id;
    ALTER TABLE ai_chat_logs MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE ai_chat_logs DROP COLUMN elder_id;
    ALTER TABLE ai_chat_logs ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- location_logs + source 枚举增加 gaode + 复合索引
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='location_logs' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='location_logs' AND column_name='elder_profile_id') THEN
    ALTER TABLE location_logs ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE location_logs SET elder_profile_id = elder_id;
    ALTER TABLE location_logs MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE location_logs DROP COLUMN elder_id;
    ALTER TABLE location_logs ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = v_db AND table_name = 'location_logs') THEN
    ALTER TABLE location_logs
      MODIFY COLUMN source ENUM('gps','wifi','beacon','sensor','gaode') NOT NULL;
  END IF;

  SELECT COUNT(*) INTO v_col
  FROM information_schema.statistics
  WHERE table_schema = v_db AND table_name = 'location_logs' AND index_name = 'idx_elder_recorded_at';
  IF v_col = 0
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = v_db AND table_name = 'location_logs' AND column_name = 'elder_profile_id') THEN
    ALTER TABLE location_logs ADD KEY idx_elder_recorded_at (elder_profile_id, recorded_at);
  END IF;

  -- activity_logs
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='activity_logs' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='activity_logs' AND column_name='elder_profile_id') THEN
    ALTER TABLE activity_logs ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE activity_logs SET elder_profile_id = elder_id;
    ALTER TABLE activity_logs MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE activity_logs DROP COLUMN elder_id;
    ALTER TABLE activity_logs ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- geofences
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='geofences' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='geofences' AND column_name='elder_profile_id') THEN
    ALTER TABLE geofences ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE geofences SET elder_profile_id = elder_id;
    ALTER TABLE geofences MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE geofences DROP COLUMN elder_id;
    ALTER TABLE geofences ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  -- emergency_alerts：列与枚举升级
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='emergency_alerts' AND column_name='elder_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=v_db AND table_name='emergency_alerts' AND column_name='elder_profile_id') THEN
    ALTER TABLE emergency_alerts ADD COLUMN elder_profile_id BIGINT NULL AFTER id;
    UPDATE emergency_alerts SET elder_profile_id = elder_id;
    ALTER TABLE emergency_alerts MODIFY elder_profile_id BIGINT NOT NULL;
    ALTER TABLE emergency_alerts DROP COLUMN elder_id;
    ALTER TABLE emergency_alerts ADD KEY idx_elder_profile_id (elder_profile_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = v_db AND table_name = 'emergency_alerts') THEN
    SELECT COUNT(*) INTO v_col
    FROM information_schema.columns
    WHERE table_schema = v_db AND table_name = 'emergency_alerts' AND column_name = 'revoke_deadline';
    IF v_col = 0 THEN
      ALTER TABLE emergency_alerts
        ADD COLUMN revoke_deadline DATETIME DEFAULT NULL AFTER trigger_time,
        ADD COLUMN sent_time DATETIME DEFAULT NULL AFTER revoke_deadline,
        ADD COLUMN cancel_mode ENUM('button','voice','system') DEFAULT NULL AFTER cancel_time;
      UPDATE emergency_alerts SET sent_time = trigger_time WHERE status IN ('sent','handled','false_alarm','cancelled') AND sent_time IS NULL;
    END IF;

    ALTER TABLE emergency_alerts
      MODIFY COLUMN trigger_mode ENUM('button','voice','sensor','rule_engine') DEFAULT 'button',
      MODIFY COLUMN status ENUM('pending_revoke','sent','cancelled','handled','false_alarm') NOT NULL;

    SELECT COUNT(*) INTO v_col
    FROM information_schema.statistics
    WHERE table_schema = v_db AND table_name = 'emergency_alerts' AND index_name = 'idx_revoke_deadline';
    IF v_col = 0 THEN
      ALTER TABLE emergency_alerts ADD KEY idx_revoke_deadline (revoke_deadline);
    END IF;
  END IF;

END $$

DELIMITER ;

CALL sp_migrate_legacy_elder_to_v4();
DROP PROCEDURE IF EXISTS sp_migrate_legacy_elder_to_v4;

-- 若 location_logs 已在 V4 但缺少复合索引 / gaode，可手工执行：
-- ALTER TABLE location_logs MODIFY source ENUM('gps','wifi','beacon','sensor','gaode') NOT NULL;
-- ALTER TABLE location_logs ADD KEY idx_elder_recorded_at (elder_profile_id, recorded_at);
