-- ======================================================
-- 从 V8 增量升级到 V9：新增 elder_location_guard_settings
-- 适用：已在 elder 库执行过 table_v8 + initial 或线上 V8
-- 执行后：为每个 elder_profiles 行生成/更新一条守护设置
-- ======================================================

USE elder;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS elder_location_guard_settings (
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

INSERT INTO elder_location_guard_settings (
  elder_profile_id, enabled, mode, interval_seconds, outside_interval_seconds,
  background_required, foreground_granted, background_granted, battery_optimization_ignored,
  last_upload_at, updated_by, updated_at, created_at
)
SELECT
  ep.id,
  0 AS enabled,
  'off' AS mode,
  600 AS interval_seconds,
  300 AS outside_interval_seconds,
  1 AS background_required,
  COALESCE(ep.location_permission_foreground, 0) AS foreground_granted,
  COALESCE(ep.location_permission_background, 0) AS background_granted,
  0 AS battery_optimization_ignored,
  latest.last_upload_at,
  ep.claimed_user_id AS updated_by,
  NOW() AS updated_at,
  NOW() AS created_at
FROM elder_profiles ep
LEFT JOIN (
  SELECT elder_profile_id, MAX(recorded_at) AS last_upload_at
  FROM location_logs
  GROUP BY elder_profile_id
) latest ON latest.elder_profile_id = ep.id
ON DUPLICATE KEY UPDATE
  foreground_granted = VALUES(foreground_granted),
  background_granted = VALUES(background_granted),
  last_upload_at = COALESCE(elder_location_guard_settings.last_upload_at, VALUES(last_upload_at)),
  updated_at = NOW();
